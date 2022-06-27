# frozen_string_literal: true
module Kubernetes
  class ReleaseDoc < ActiveRecord::Base
    self.table_name = 'kubernetes_release_docs'

    belongs_to :kubernetes_role, class_name: 'Kubernetes::Role', inverse_of: false
    belongs_to :kubernetes_release, class_name: 'Kubernetes::Release', inverse_of: :release_docs
    belongs_to :deploy_group, inverse_of: false

    serialize :resource_template, JSON

    validates :deploy_group, presence: true
    validates :kubernetes_role, presence: true
    validates :kubernetes_release, presence: true
    validate :validate_config_file, on: :create

    before_create :store_resource_template

    attr_reader :previous_resources
    attr_writer :deploy_group_role
    attr_accessor :created_cluster_resources

    delegate :blue_green?, to: :kubernetes_role

    def deploy
      @previous_resources = resources.map(&:resource)
      resources.each(&:deploy)
    end

    # not used when deploying, just as fallback when building things from the console
    def deploy_group_role
      @deploy_group_role ||= DeployGroupRole.where(kubernetes_role: kubernetes_role, deploy_group: deploy_group).first!
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
      verification_templates(main_only: true).each(&:verify)
    end

    # kubeclient needs pure symbol hash ... not indifferent access
    def resource_template
      @resource_template ||= Array.wrap(super).map(&:deep_symbolize_keys)
    end

    def resources
      @resources ||= begin
        resources = resource_template.map do |template|
          Kubernetes::Resource.build(
            template,
            deploy_group,
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

    # Temporary templates to run validations on ... so can be cheap / not fully fleshed out
    # we check main_only in here to avoid generating all the extra fillers just to throw them away
    def verification_templates(main_only: false)
      templates = raw_template
      templates = [templates.detect { |t| Kubernetes::RoleConfigFile.primary?(t) } || templates.first] if main_only
      templates.each_with_index.map { |c, i| Kubernetes::TemplateFiller.new(self, c, index: i) }
    end

    def blue_green_color
      kubernetes_release.blue_green_color if blue_green?
    end

    def prerequisite?
      resources.any?(&:prerequisite?)
    end

    def desired_pod_count
      resources.sum(&:desired_pod_count)
    end

    def build_selectors
      verification_templates(main_only: true).first.build_selectors
    end

    def deploy_metadata
      @deploy_metadata ||= Kubernetes::Release.
        pod_selector(kubernetes_release.id, deploy_group.id, query: false).
        merge(
          deploy_id: kubernetes_release.deploy_id,
          project_id: kubernetes_release.project_id,
          role_id: kubernetes_role.id,
          deploy_group: deploy_group.env_value,
          revision: kubernetes_release.git_sha,
          tag: kubernetes_release.git_ref
        )
    end

    def static_env
      @static_env ||= begin
        env = {}

        [:REVISION, :TAG, :DEPLOY_ID, :DEPLOY_GROUP].each do |k|
          env[k.to_s] = deploy_metadata.fetch(k.downcase).to_s.dup # .dup since nil.to_s is frozen ""
        end

        [:PROJECT, :ROLE].each do |k|
          env[k.to_s] = raw_template.first.dig_fetch(:metadata, :labels, k.downcase).dup
        end

        # name of the cluster
        env["KUBERNETES_CLUSTER_NAME"] = deploy_group.kubernetes_cluster.name.to_s

        # blue-green phase
        env["BLUE_GREEN"] = blue_green_color.dup if blue_green?

        # env from plugins
        deploy = kubernetes_release.deploy || Deploy.new(project: kubernetes_release.project)
        plugin_envs = Samson::Hooks.fire(:deploy_env, deploy, deploy_group, resolve_secrets: false, base: env)
        plugin_envs.compact.inject({}, :merge!)
      end
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
      return if raw_template.any? { |r| r[:kind] == "PodDisruptionBudget" }
      return unless target = disruption_budget_target(deployment)

      annotations = (deployment.dig(:metadata, :annotations) || {}).slice(
        :"samson/override_project_label",
        :"samson/keep_name"
      )

      budget = {
        apiVersion: "policy/v1",
        kind: "PodDisruptionBudget",
        metadata: {
          name: deployment.dig(:metadata, :name),
          labels: deployment.dig_fetch(:metadata, :labels).dup,
          annotations: annotations
        },
        spec: {
          maxUnavailable: target,
          selector: {matchLabels: deployment.dig_fetch(:spec, :selector, :matchLabels).dup}
        }
      }

      if deployment[:metadata].key? :namespace
        budget[:metadata][:namespace] = deployment.dig(:metadata, :namespace)
      end

      # not HA: don't bother, overhead for 0 or 1 replica deployments, but we don't know if a bad budget existed before
      budget[:delete] = true if replica_target <= 1

      raw_template << budget
    end

    # covert minAvailable to maxUnavailable because that never results in blocking the cluster from draining nodes
    # (math can go wrong and PDBs cannot be drained for example because HPA scaled the deployment down)
    def disruption_budget_target(deployment)
      min_available = deployment.dig(:metadata, :annotations, :"samson/minAvailable")
      return if min_available == "disabled"

      min_available ||= ENV["KUBERNETES_AUTO_MIN_AVAILABLE"]
      return unless min_available

      if percent = min_available.to_s[/\A(\d+)\s*%\z/, 1] # "30%" -> 30 / "30 %" -> 30
        "#{[100 - Integer(percent), 1].max}%"
      else
        [replica_target - Integer(min_available), 1].max
      end
    end

    def validate_config_file
      return unless kubernetes_role
      raw_template # trigger RoleConfigFile validations
    rescue Samson::Hooks::UserError
      errors.add(:kubernetes_release, $!.message)
    end

    def raw_template
      @raw_template ||=
        kubernetes_role.role_config_file(
          kubernetes_release.git_sha,
          project: kubernetes_release.project, pull: true, deploy_group: deploy_group
        ).elements
    end
  end
end
