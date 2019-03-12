# frozen_string_literal: true
# fills out Deploy/Job template with dynamic values
module Kubernetes
  class TemplateFiller
    attr_reader :template

    CUSTOM_UNIQUE_LABEL_KEY = 'rc_unique_identifier'
    SECRET_PULLER_IMAGE = ENV['SECRET_PULLER_IMAGE'].presence
    KUBERNETES_ADD_PRESTOP = Samson::EnvCheck.set?('KUBERNETES_ADD_PRESTOP')
    SECRET_PREFIX = "secret/"
    DOCKERFILE_NONE = 'none'

    def initialize(release_doc, template, index:)
      @doc = release_doc
      @template = template.deep_dup
      @index = index
    end

    def to_hash(verification: false)
      @to_hash ||= begin
        kind = template[:kind]

        set_via_env_json
        set_namespace unless Kubernetes::RoleValidator::NAMESPACELESS_KINDS.include? kind
        set_project_labels if template.dig(:metadata, :annotations, :"samson/override_project_label")
        set_deploy_url

        if RoleValidator::IMMUTABLE_NAME_KINDS.include?(kind)
          # names have a fixed pattern so we cannot override them
        elsif kind == 'HorizontalPodAutoscaler'
          set_name
          set_hpa_scale_target_name
        elsif Kubernetes::RoleConfigFile::SERVICE_KINDS.include?(kind)
          set_service_name
          prefix_service_cluster_ip
          set_service_blue_green if blue_green_color
        elsif Kubernetes::RoleConfigFile.primary?(template)
          if kind != 'Pod'
            set_rc_unique_label_key
            set_history_limit
          end

          set_replica_target || validate_replica_target_is_supported

          make_stateful_set_match_service if kind == 'StatefulSet'
          set_pre_stop if kind == 'Deployment'

          set_name
          set_spec_template_metadata
          set_docker_image unless verification
          set_resource_usage
          set_env
          set_secrets
          set_image_pull_secrets
          set_resource_blue_green if blue_green_color
          set_init_containers
        elsif kind == 'PodDisruptionBudget'
          set_name
          set_match_labels_blue_green if blue_green_color
        else
          set_name
        end

        template
      end
    end

    def verify
      verify_env
      set_secrets
    end

    def build_selectors
      all = containers + init_containers
      all.each_with_index.map { |c, i| build_selector_for_container(c, first: i == 0, scan: true) }.compact
    end

    private

    def set_via_env_json
      (template[:metadata][:annotations] || {}).dup.each do |k, v|
        next unless path = k[/^(?:samson\/set_via_env_json|samson-set-via-env-json)-(.*)/, 1]
        path = path.split(/\.(labels|annotations)\./) # make sure we do not split inside of labels or annotations
        path[0..0] = path[0].split(".")
        path.map! { |k| k.match?(/^\d+$/) ? Integer(k) : k.to_sym }

        begin
          template.dig_set(path, JSON.parse(static_env.fetch(v), symbolize_names: true))
        rescue KeyError, JSON::ParserError => e
          raise Samson::Hooks::UserError, "Unable to set key #{k}: #{e.class} #{e.message}"
        end
      end
    end

    def build_selector_for_container(container, first:, scan:)
      dockerfile = samson_container_config(container, :"samson/dockerfile") ||
        (!first && ENV['KUBERNETES_ADDITIONAL_CONTAINERS_WITHOUT_DOCKERFILE'] ? DOCKERFILE_NONE : 'Dockerfile')

      if dockerfile == DOCKERFILE_NONE
        Samson::Hooks.fire :ensure_docker_image_has_no_vulnerabilities, stage, container.fetch(:image) if scan && stage
        return
      end

      if project.docker_image_building_disabled?
        # also supporting dockerfile would make sense if external builds did not have image_name,
        # maybe even Dockerfile.foo -> <permalink>-foo translation
        # but for now keeping old behavior
        [nil, container.fetch(:image)]
      else
        [dockerfile, nil]
      end
    end

    # samson/ keys in containers trigger validation warnings in kubectl, so we allow using annotations too
    # NOTE: containers always have a name see role_validator.rb
    def samson_container_config(container, key)
      pod_annotations[samson_container_config_key(container, key)] || container[key]
    end

    def samson_container_config_key(container, key)
      :"container-#{container.fetch(:name)}-#{key}"
    end

    def set_deploy_url
      [template, pod_template].compact.each do |t|
        annotations = (t[:metadata][:annotations] ||= {})
        annotations[:"samson/deploy_url"] = @doc.kubernetes_release.deploy&.url
      end
    end

    def set_service_blue_green
      template.dig_set([:spec, :selector, :blue_green], blue_green_color)
    end

    def set_resource_blue_green
      template.dig_set([:metadata, :labels, :blue_green], blue_green_color)
      set_match_labels_blue_green
      template.dig_set([:spec, :template, :metadata, :labels, :blue_green], blue_green_color)
    end

    def set_match_labels_blue_green
      template.dig_set([:spec, :selector, :matchLabels, :blue_green], blue_green_color)
    end

    # TODO: unify into with label verification logic in role_validator
    def set_project_labels
      [
        [:metadata, :labels],
        [:spec, :selector],
        [:spec, :selector, :matchLabels],
        [:spec, :template, :metadata, :labels],
        [:spec, :jobTemplate, :spec, :template, :metadata, :labels]
      ].each do |path|
        template.dig(*path)[:project] = project.permalink if template.dig(*path, :project)
      end
    end

    def keep_name?
      template.dig(:metadata, :annotations, :'samson/keep_name') == 'true'
    end

    def set_service_name
      return if keep_name?
      template[:metadata][:name] = generate_service_name(template[:metadata][:name])
    end

    def generate_service_name(config_name)
      # when no service name was chosen we use the name from the config, which could lead to duplication
      return config_name unless name = @doc.kubernetes_role.service_name.presence

      if name.include?(Kubernetes::Role::GENERATED)
        raise(
          Samson::Hooks::UserError,
          "Service name for role #{@doc.kubernetes_role.name} was generated while seeding " \
          "and needs to be changed via kubernetes role UI before deploying."
        )
      end

      # users can only enter a single service-name so for each additional service we make up a name
      # unless the given name already fits the pattern ... slight chance that it might end up being not unique
      # this is to enable `foo-http` / `foo-grpc` style services
      return config_name if config_name.start_with?(name) && config_name.size > name.size

      name += "-#{@index + 1}" if @index > 0
      name
    end

    # no ipv6 support
    def prefix_service_cluster_ip
      return unless ip = template[:spec][:clusterIP]
      return if ip == "None"
      return unless prefix = @doc.deploy_group.kubernetes_cluster.ip_prefix.presence
      ip = ip.split('.')
      prefix = prefix.split('.')
      ip[0...prefix.size] = prefix
      template[:spec][:clusterIP] = ip.join('.')
    end

    def set_namespace
      return if template.dig(:metadata, :labels, :'kubernetes.io/cluster-service') == 'true'
      return if template.dig(:metadata, :annotations, :'samson/keep_namespace') == 'true'
      template[:metadata][:namespace] = @doc.deploy_group.kubernetes_namespace
    end

    # If the user renames the service the StatefulSet will not match it, so we fix.
    # Will not work with multiple services ... but that usecase hopefully does not exist.
    def make_stateful_set_match_service
      return unless template[:spec][:serviceName]
      return unless service_name = @doc.kubernetes_role.service_name.presence
      template[:spec][:serviceName] = service_name
    end

    # make sure we clean up old replicasets
    # we never rollback since that might be a rollback to a broken release (failed during stability test)
    # but still keep 1 around so we can do a manual `kubectl rollback` if something goes horribly wrong
    # see discussion in https://github.com/kubernetes/kubernetes/issues/23597
    def set_history_limit
      template[:spec][:revisionHistoryLimit] ||= 1
    end

    # replace keys in annotations by looking them up in all possible namespaces by specificity
    # also supports wildcard expansion
    def expand_secret_annotations
      resolver = Samson::Secrets::KeyResolver.new(project, [@doc.deploy_group])
      secret_annotations.each do |k, v|
        annotations = pod_annotations
        annotations.delete(k)
        resolver.expand(k, v).each { |k, v| annotations[k.to_sym] = v }
      end
      resolver.verify!
    end

    def pod_annotations
      pod_template ? pod_template[:metadata][:annotations] ||= {} : {}
    end

    def pod_template
      return @pod_template if defined?(@pod_template)
      @pod_template = RoleConfigFile.templates(template).first
    end

    def secret_annotations
      pod_annotations.select do |annotation_name, _|
        annotation_name.to_s.start_with?(SECRET_PREFIX)
      end
    end

    # Sets up the secret-puller and the various mounts that are required
    # if the secret-puller service is enabled
    # /vaultauth is a secrets volume in the cluster
    # /secretkeys are where the annotations from the config are mounted
    def set_secret_puller
      secret_vol = {mountPath: "/secrets", name: "secrets-volume"}
      container = {
        image: SECRET_PULLER_IMAGE,
        imagePullPolicy: 'IfNotPresent',
        name: 'secret-puller',
        volumeMounts: [
          {mountPath: "/vault-auth", name: "vaultauth"},
          {mountPath: "/secretkeys", name: "secretkeys"},
          secret_vol
        ],
        env: vault_env
      }
      init_containers.unshift container

      # mark the container as not needing a dockerfile without making the pod invalid for kubelet
      pod_annotations[samson_container_config_key(container, "samson/dockerfile")] = DOCKERFILE_NONE

      # share secrets volume between all containers
      containers.each do |container|
        (container[:volumeMounts] ||= []).push secret_vol
      end

      # define the shared volumes in the pod
      (pod_template[:spec][:volumes] ||= []).concat [
        {name: secret_vol.fetch(:name), emptyDir: {medium: 'Memory'}},
        {name: "vaultauth", secret: {secretName: "vaultauth"}},
        {
          name: "secretkeys",
          downwardAPI: {
            items: [{path: "annotations", fieldRef: {fieldPath: "metadata.annotations"}}]
          }
        }
      ]
    end

    # Init containers are stored as a json annotation
    # see http://kubernetes.io/docs/user-guide/production-pods/#handling-initialization
    def set_init_containers
      return if init_containers.empty?
      key = Kubernetes::Api::Pod::INIT_CONTAINER_KEY
      if init_containers_in_beta?
        pod_template.dig_set([:spec, :initContainers], init_containers)
        pod_annotations.delete(key)
      else
        pod_annotations[key] = JSON.pretty_generate(init_containers)
        pod_template[:spec].delete(:initContainers)
      end
    end

    def init_containers_in_beta?
      @doc.deploy_group.kubernetes_cluster.server_version >= Gem::Version.new('1.6.0')
    end

    # This key replaces the default kubernetes key: 'deployment.kubernetes.io/podTemplateHash'
    # This label is used by kubernetes to identify a RC and corresponding Pods
    def set_rc_unique_label_key
      template.dig_set [:spec, :uniqueLabelKey], CUSTOM_UNIQUE_LABEL_KEY
    end

    def set_replica_target
      key = [:spec, :replicas]
      target =
        if ['StatefulSet', 'Deployment'].include?(template[:kind])
          template
        else
          # custom resource that has replicas set on itself or it's template
          containers = [template] + (template[:spec] || {}).values_at(*RoleConfigFile.template_keys(template))
          containers.detect { |c| c.dig(*key) }
        end

      target&.dig_set key, @doc.replica_target
    end

    def validate_replica_target_is_supported
      return if @doc.replica_target == 1 || (@doc.replica_target == 0 && @doc.delete_resource)
      raise(
        Samson::Hooks::UserError,
        "#{template[:kind]} #{@doc.kubernetes_role.resource_name} is set to #{@doc.replica_target} replicas, " \
        "which is not supported. Set it to 1 replica to keep deploying it or marked it for deletion."
      )
    end

    def set_name
      name = if keep_name?
        template.dig_fetch(:metadata, :name)
      else
        @doc.kubernetes_role.resource_name
      end
      name += "-#{blue_green_color}" if blue_green_color
      template.dig_set [:metadata, :name], name
    end

    def set_hpa_scale_target_name
      template.dig_set [:spec, :scaleTargetRef, :name], @doc.kubernetes_role.resource_name
    end

    # Sets the labels for each new Pod.
    # Adding the Release ID to allow us to track the progress of a new release from the UI.
    def set_spec_template_metadata
      release_doc_metadata.each do |key, value|
        pod_template.dig_fetch(:metadata, :labels)[key] ||= value.to_s
      end
    end

    def release_doc_metadata
      @release_doc_metadata ||= begin
        release = @doc.kubernetes_release
        role = @doc.kubernetes_role
        deploy_group = @doc.deploy_group

        Kubernetes::Release.pod_selector(release.id, deploy_group.id, query: false).merge(
          deploy_id: release.deploy_id,
          project_id: release.project_id,
          role_id: role.id,
          deploy_group: deploy_group.env_value.parameterize.tr('_', '-'),
          revision: release.git_sha,
          tag: release.git_ref.parameterize.tr('_', '-')
        )
      end
    end

    def set_resource_usage
      containers.first[:resources] = {
        requests: {cpu: @doc.requests_cpu.to_f, memory: "#{@doc.requests_memory}M"},
        limits: {cpu: @doc.limits_cpu.to_f, memory: "#{@doc.limits_memory}M"}
      }
      containers.first[:resources][:limits].delete(:cpu) if @doc.no_cpu_limit
    end

    def set_docker_image
      builds = @doc.kubernetes_release.builds
      set_docker_image_for_containers(builds, containers + init_containers)
    end

    def set_docker_image_for_containers(builds, containers)
      containers.each_with_index do |container, i|
        next unless build_selector = build_selector_for_container(container, first: i == 0, scan: false)
        build = Samson::BuildFinder.detect_build_by_selector!(builds, *build_selector,
          fail: true, project: project)
        container[:image] = build.docker_repo_digest
        container[:imagePullPolicy] = 'IfNotPresent' if container[:imagePullPolicy] == 'Always'
      end
    end

    def project
      @project ||= @doc.kubernetes_release.project
    end

    def stage
      @stage ||= @doc.kubernetes_release&.deploy&.stage
    end

    # custom annotation we support here and in kucodiff
    def missing_env
      test_env = containers.flat_map { |c| c[:env] ||= [] }
      (required_env - test_env.map { |e| e.fetch(:name) }).presence
    end

    def required_env
      (pod_annotations[:"samson/required_env"] || "").strip.split(/[\s,]+/)
    end

    def verify_env
      return unless missing_env # save work when there will be nothing to do
      set_env
      return unless missing = missing_env
      raise Samson::Hooks::UserError, "Missing env variables #{missing.inspect}"
    end

    # helpful env vars, also useful for log tagging
    def set_env
      all = []

      all.concat vault_env if vault_env_required?

      static_env.each { |k, v| all << {name: k.to_s, value: v.to_s} }

      # dynamic lookups for unknown things during deploy
      {
        POD_NAME: 'metadata.name',
        POD_NAMESPACE: 'metadata.namespace',
        POD_IP: 'status.podIP'
      }.each do |k, v|
        all << {
          name: k.to_s,
          valueFrom: {fieldRef: {fieldPath: v}}
        }
      end

      containers.each do |c|
        env = (c[:env] ||= [])
        env.concat all

        # unique, but keep last elements
        env.reverse!
        env.uniq! { |h| h[:name] }
        env.reverse!
      end
    end

    def static_env
      @static_env ||= begin
        env = {}

        metadata = release_doc_metadata
        [:REVISION, :TAG, :DEPLOY_ID, :DEPLOY_GROUP].each do |k|
          env[k] = metadata.fetch(k.downcase)
        end

        [:PROJECT, :ROLE].each do |k|
          env[k] = template.dig_fetch(:metadata, :labels, k.downcase)
        end

        # name of the cluster
        kube_cluster_name = DeployGroup.find(metadata[:deploy_group_id]).kubernetes_cluster.name.to_s
        env[:KUBERNETES_CLUSTER_NAME] = kube_cluster_name

        # blue-green phase
        env[:BLUE_GREEN] = blue_green_color if blue_green_color

        # env from plugins
        plugin_envs = Samson::Hooks.fire(:deploy_group_env, project, @doc.deploy_group, stage, resolve_secrets: false)
        plugin_envs += Samson::Hooks.fire(:deploy_env, @doc.kubernetes_release.deploy) if @doc.kubernetes_release.deploy
        plugin_envs.compact.inject(env, :merge!)
      end
    end

    def set_secrets
      return unless SECRET_PULLER_IMAGE
      convert_secret_env_to_annotations if secret_env_as_annotations?
      return unless secret_annotations.any?
      set_secret_puller
      expand_secret_annotations
    end

    def secret_env_as_annotations?
      ENV["SECRET_ENV_AS_ANNOTATIONS"]
    end

    # storing secrets as env vars makes them visible in the deploy docs and when inspecting deployments, to avoid it
    # we replace all secrets from the env here and they are expanded by expand_secret_annotations later
    def convert_secret_env_to_annotations
      converted = []
      containers.each do |c|
        c.fetch(:env).reject! do |var|
          next unless value = var[:value]
          next true if converted.include?(value)
          next unless secret_key = value.dup.sub!(/^#{Regexp.escape TerminalExecutor::SECRET_PREFIX}/, '')
          converted << value

          key = "#{SECRET_PREFIX}#{var.fetch(:name)}".to_sym
          if (old = pod_annotations[key]) && old != secret_key
            raise(
              Samson::Hooks::UserError,
              "Annotation key #{key} is already set to #{old}, cannot set it via environment to #{secret_key}.\n" \
              "Either delete the environment variable or make them both point to the same key."
            )
          end
          pod_annotations[key] = secret_key
        end
      end
    end

    def blue_green_color
      return @blue_green_color if defined?(@blue_green_color)
      @blue_green_color = @doc.blue_green_color
    end

    def vault_env_required?
      required_env.include?('VAULT_ADDR') && ENV["SECRET_STORAGE_BACKEND"] == "Samson::Secrets::HashicorpVaultBackend"
    end

    def vault_env
      vault_client = Samson::Secrets::VaultClientManager.instance.client(@doc.deploy_group.permalink)
      [
        {name: "VAULT_ADDR", value: vault_client.options.fetch(:address)},
        {name: "VAULT_SSL_VERIFY", value: vault_client.options.fetch(:ssl_verify).to_s},
        {name: "VAULT_MOUNT", value: Samson::Secrets::VaultClientManager::MOUNT},
        {name: "VAULT_PREFIX", value: Samson::Secrets::VaultClientManager::PREFIX},
        {name: "VAULT_KV_V2", value: vault_client.versioned_kv.to_s}
      ]
    end

    # kubernetes needs docker secrets to be able to pull down images from the registry
    # in kubernetes 1.3 this might work without this workaround
    def set_image_pull_secrets
      cluster = @doc.deploy_group.kubernetes_cluster
      docker_configs = ['kubernetes.io/dockercfg', 'kubernetes.io/dockerconfigjson']

      docker_credentials = Rails.cache.fetch(["docker_credentials", cluster], expires_in: 1.hour) do
        secrets = SamsonKubernetes.retry_on_connection_errors do
          cluster.client('v1').get_secrets(namespace: template.dig_fetch(:metadata, :namespace)).fetch(:items)
        end
        secrets.
          select { |secret| docker_configs.include? secret.fetch(:type) }.
          map! { |c| {name: c.dig(:metadata, :name)} }
      end

      return if docker_credentials.empty?

      pod_template.fetch(:spec)[:imagePullSecrets] = docker_credentials
    end

    def set_pre_stop
      return unless KUBERNETES_ADD_PRESTOP
      containers.each do |container|
        next if samson_container_config(container, :"samson/preStop") == "disabled"
        (container[:lifecycle] ||= {})[:preStop] ||= {exec: {command: ["sleep", "3"]}}
      end
    end

    def init_containers
      @init_containers ||= (pod_template ? Api::Pod.init_containers(pod_template) : [])
    end

    def containers
      pod_template ? pod_template.dig_fetch(:spec, :containers) : []
    end
  end
end
