# frozen_string_literal: true
module Kubernetes
  class ReleaseDoc < ActiveRecord::Base
    self.table_name = 'kubernetes_release_docs'

    belongs_to :kubernetes_role, class_name: 'Kubernetes::Role', inverse_of: nil
    belongs_to :kubernetes_release, class_name: 'Kubernetes::Release', inverse_of: :release_docs
    belongs_to :deploy_group, inverse_of: nil

    serialize :resource_template, JSON
    delegate :build_selectors, to: :verification_template

    validates :deploy_group, presence: true, inverse_of: nil
    validates :kubernetes_role, presence: true
    validates :kubernetes_release, presence: true
    validate :validate_config_file, on: :create

    before_create :store_resource_template

    attr_reader :previous_resources

    def deploy
      @previous_resources = resources.map(&:resource)
      resources.each(&:deploy)
    end

    def revert
      raise "Can only be done after a deploy" unless @previous_resources
      resources.each_with_index do |resource, i|
        resource.revert(@previous_resources[i])
      end
    end

    # run on unsaved mock ReleaseDoc to test template and secrets before we save or create a build
    # this create a bit of duplicated work, but fails the deploy fast
    def verify_template
      verification_template.verify
    end

    # kubeclient needs pure symbol hash ... not indifferent access
    def resource_template
      @resource_template ||= Array.wrap(super).map(&:deep_symbolize_keys)
    end

    def resources
      @resources ||= begin
        resources = resource_template.map do |t|
          Kubernetes::Resource.build(
            t, deploy_group,
            autoscaled: kubernetes_role.autoscaled,
            delete_resource: delete_resource
          )
        end
        resources.sort_by do |r|
          Kubernetes::RoleConfigFile::DEPLOY_SORT_ORDER.index(r.kind) ||
            Kubernetes::RoleConfigFile::DEPLOY_SORT_ORDER.size # default to maximum value
        end
      end
    end

    # Temporary template we run validations on ... so can be cheap / not fully fleshed out
    # and only be the primary since services/configmaps are not very interesting anyway
    def verification_template
      primary_config = raw_template.detect { |e| Kubernetes::RoleConfigFile.primary?(e) } || raw_template.first
      Kubernetes::TemplateFiller.new(self, primary_config, index: 0)
    end

    def blue_green_color
      kubernetes_release.blue_green_color if kubernetes_role.blue_green?
    end

    def prerequisite?
      resources.any?(&:prerequisite?)
    end

    def desired_pod_count
      resources.sum(&:desired_pod_count)
    end

    private

    def resource_template=(value)
      @resource_template = nil
      super
    end

    # dynamically fill out the templates and store the result
    def store_resource_template
      add_pod_disruption_budget
      counter = Hash.new(-1)
      self.resource_template = raw_template.map do |resource|
        index = (counter[resource.fetch(:kind)] += 1)
        TemplateFiller.new(self, resource, index: index).to_hash
      end
    end

    def add_pod_disruption_budget
      return unless deployment = raw_template.detect { |r| ["Deployment", "StatefulSet"].include? r[:kind] }
      return unless target = disruption_budget_target(deployment)

      annotations = (deployment.dig(:metadata, :annotations) || {}).slice(
        :"samson/override_project_label",
        :"samson/keep_name"
      )
      annotations[:"samson/updateTimestamp"] = Time.now.utc.iso8601

      budget = {
        apiVersion: "policy/v1beta1",
        kind: "PodDisruptionBudget",
        metadata: {
          name: deployment.dig(:metadata, :name),
          labels: deployment.dig_fetch(:metadata, :labels).dup,
          annotations: annotations
        },
        spec: {
          minAvailable: target,
          selector: {
            matchLabels: deployment.
              dig_fetch(:spec, :selector, :matchLabels).
              merge(samsonAutoPDB: 'true')
          }
        }
      }

      deployment.dig_fetch(:metadata, :labels)[:samsonAutoPDB] = 'true'

      if deployment[:metadata].key? :namespace
        budget[:metadata][:namespace] = deployment.dig(:metadata, :namespace)
      end
      budget[:delete] = true if target == 0
      raw_template << budget
    end

    def disruption_budget_target(deployment)
      min_available = deployment.dig(:metadata, :annotations, :"samson/minAvailable")
      return if min_available == "disabled"

      # NOTE: overhead for 0 or 1 replica deployments, but we don't know if a bad budget existed before
      min_available ||= ENV["KUBERNETES_AUTO_MIN_AVAILABLE"]
      return unless min_available

      non_blocking = replica_target - 1
      return 0 if non_blocking <= 0

      if percent = min_available.to_s[/\A(\d+)\s*%\z/, 1] # "30%" -> 30 / "30 %" -> 30
        percent = Integer(percent)
        if percent >= 100
          raise Samson::Hooks::UserError, "minAvailable of >= 100% would result in eviction deadlock, pick lower"
        else
          "#{[percent, non_blocking.to_f / replica_target * 100].min.to_i}%"
        end
      else
        [non_blocking, Integer(min_available)].min
      end
    end

    def validate_config_file
      return unless kubernetes_role
      raw_template # trigger RoleConfigFile validations
    rescue Samson::Hooks::UserError
      errors.add(:kubernetes_release, $!.message)
    end

    def raw_template
      @raw_template ||= begin
        file = kubernetes_role.config_file
        content = kubernetes_release.project.repository.file_content(file, kubernetes_release.git_sha)
        RoleConfigFile.new(content, file, project: kubernetes_release.project).elements
      end
    end
  end
end
