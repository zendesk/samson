# frozen_string_literal: true
module Kubernetes
  class ReleaseDoc < ActiveRecord::Base
    self.table_name = 'kubernetes_release_docs'

    belongs_to :kubernetes_role, class_name: 'Kubernetes::Role', inverse_of: false
    belongs_to :kubernetes_release, class_name: 'Kubernetes::Release', inverse_of: :release_docs
    belongs_to :deploy_group, inverse_of: false

    serialize :resource_template, JSON

    validates :deploy_group, presence: true, inverse_of: false
    validates :kubernetes_role, presence: true
    validates :kubernetes_release, presence: true
    validate :validate_config_file, on: :create

    before_create :store_resource_template

    attr_reader :previous_resources
    attr_writer :deploy_group_role

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

    def custom_resource_definitions
      resource_template.select { |t| t[:kind] == "CustomResourceDefinition" }.map do |t|
        [t.dig(:spec, :names, :kind), {"namespaced" => t.dig(:spec, :scope) == "Namespaced"}]
      end.to_h
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
          env[k.to_s] = deploy_metadata.fetch(k.downcase).to_s
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

    def metadata
      @metadata ||=
        Kubernetes::Release.pod_selector(kubernetes_release.id, deploy_group.id, query: false).merge(
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
          env[k.to_s] = metadata.fetch(k.downcase).to_s
        end

        if reference_resource
          [:PROJECT, :ROLE].each do |k|
            env[k.to_s] = reference_resource.dig_fetch(:metadata, :labels, k.downcase).dup
          end
        end

        # name of the cluster
        env["KUBERNETES_CLUSTER_NAME"] = deploy_group.kubernetes_cluster.name.to_s

        # blue-green phase
        env["BLUE_GREEN"] = blue_green_color.dup if blue_green_color

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
      add_env_config_map

      counter = Hash.new(-1)

      self.resource_template = raw_template.map do |resource|
        index = (counter[resource.fetch(:kind)] += 1)
        opts = {index: index}
        opts[:env_config_map] = env_config_map_name if env_from_config_map?
        TemplateFiller.new(self, resource, **opts).to_hash
      end
    end

    # The resource we want to copy things from, like name, labels, and annotations
    def reference_resource
      return @reference_resource if defined?(@reference_resource)
      @reference_resource = raw_template.find { |r| %w[Deployment StatefulSet].include?(r[:kind]) }
    end

    def reference_name
      reference_resource&.dig(:metadata, :name)
    end

    def reference_namespace
      reference_resource&.dig(:metadata, :namespace)
    end

    def reference_labels
      reference_resource&.dig(:metadata, :labels) || {}
    end

    def reference_annotations
      reference_resource&.dig(:metadata, :annotations) || {}
    end

    def add_pod_disruption_budget
      return unless reference_resource
      return if raw_template.any? { |r| r[:kind] == "PodDisruptionBudget" }
      return unless target = disruption_budget_target(reference_resource)

      annotations = reference_annotations.slice(
        :"samson/override_project_label",
        :"samson/keep_name"
      )
      annotations[:"samson/updateTimestamp"] = Time.now.utc.iso8601

      budget = {
        apiVersion: "policy/v1beta1",
        kind: "PodDisruptionBudget",
        metadata: {
          name: reference_name,
          labels: reference_labels.dup,
          annotations: annotations
        },
        spec: {
          minAvailable: target,
          selector: {matchLabels: reference_resource.dig_fetch(:spec, :selector, :matchLabels).dup}
        }
      }
      if ns = reference_namespace
        budget[:metadata][:namespace] = ns
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

    def add_env_config_map
      return unless env_from_config_map?
      return if env_config_map_exists?

      annotations = reference_annotations.
        slice(:"samson/override_project_label").
        merge(
          "samson/updateTimestamp": Time.now.utc.iso8601,
          "samson/envConfigMap": true
        )

      cm = {
        apiVersion: "v1",
        kind: "ConfigMap",
        metadata: {
          name: env_config_map_name,
          labels: reference_labels,
          annotations: annotations
        },
        immutable: true,
        data: static_env
      }

      if ns = reference_namespace
        cm[:metadata][:namespace] = ns
      end

      raw_template << cm
    end

    def env_config_map_exists?
      raw_template.any? { |r| r[:kind] == "ConfigMap" && r.dig(:metadata, :annotations, :"samson/envConfigMap") }
    end

    def env_from_config_map?
      !!reference_resource&.dig(:metadata, :annotations, :"samson/env_from_config_map")
    end

    def env_config_map_name
      version = kubernetes_release.blue_green_color || "blue"
      "#{reference_name}-#{version}-env"
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
          project: kubernetes_release.project, pull: true, ignore_errors: false, deploy_group: deploy_group
        ).elements
    end
  end
end
