# frozen_string_literal: true
# fills out Deploy/Job template with dynamic values
module Kubernetes
  class TemplateFiller
    attr_reader :template

    CUSTOM_UNIQUE_LABEL_KEY = 'rc_unique_identifier'
    SECRET_PULLER_IMAGE = ENV['SECRET_PULLER_IMAGE'].presence

    def initialize(release_doc, template)
      @doc = release_doc
      @template = template
    end

    def to_hash
      @to_hash ||= begin
        if template[:kind] != 'Pod'
          set_rc_unique_label_key
          set_history_limit
        end

        set_replica_target unless ['DaemonSet', 'Pod'].include?(template[:kind])

        set_name
        set_spec_template_metadata
        set_docker_image
        set_resource_usage
        set_env
        set_secrets
        set_image_pull_secrets
        set_vault_env

        hash = template
        Rails.logger.info "Created Kubernetes hash: #{hash.to_json}"
        hash
      end
    end

    def verify_env
      return unless missing_env # save work when there will be nothing to do
      set_env
      return unless missing = missing_env
      raise Samson::Hooks::UserError, "Missing env variables #{missing.join(", ")}"
    end

    def set_secrets
      return unless needs_secret_puller?
      set_secret_puller
      expand_secret_annotations
    end

    private

    # make sure we clean up old replicasets
    # we only ever do rollback to latest release ... and the default is infinite
    # see discussion in https://github.com/kubernetes/kubernetes/issues/23597
    def set_history_limit
      template[:spec][:revisionHistoryLimit] ||= 1
    end

    # replace keys in annotations by looking them up in all possible namespaces by specificity
    def expand_secret_annotations
      resolver = Samson::Secrets::KeyResolver.new(project, [@doc.deploy_group])
      secret_annotations.each do |k, v|
        annotations.delete(k)
        resolver.expand(k, v).each { |k, v| annotations[k] = v }
      end
      resolver.verify!
    end

    def annotations
      pod_template[:metadata][:annotations]
    end

    def pod_template
      template[:kind] == 'Pod' ? template : template[:spec][:template]
    end

    def secret_annotations
      @secret_annotations ||= annotations.to_h.select do |annotation_name, _|
        annotation_name.to_s.start_with?('secret/')
      end
    end

    # Sets up the secret-puller and the various mounts that are required
    # if the secret-puller service is enabled
    # /vaultauth is a secrets volume in the cluster
    # /secretkeys are where the annotations from the config are mounted
    def set_secret_puller
      secret_vol = { mountPath: "/secrets", name: "secrets-volume" }
      unshift_init_container(
        image: SECRET_PULLER_IMAGE,
        name: 'secret-puller',
        volumeMounts: [
          { mountPath: "/vault-auth", name: "vaultauth" },
          { mountPath: "/secretkeys", name: "secretkeys" },
          secret_vol
        ],
        env: vault_env
      )

      # share secrets volume between all containers
      containers.each do |container|
        (container[:volumeMounts] ||= []).push secret_vol
      end

      # define the shared volumes in the pod
      (pod_template[:spec][:volumes] ||= []).concat [
        {name: secret_vol.fetch(:name), emptyDir: {}},
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
    def unshift_init_container(container)
      key = 'pod.beta.kubernetes.io/init-containers'
      init_containers = JSON.parse(annotations[key] || '[]')
      init_containers.unshift(container)
      annotations[key] = JSON.pretty_generate(init_containers)
    end

    # This key replaces the default kubernetes key: 'deployment.kubernetes.io/podTemplateHash'
    # This label is used by kubernetes to identify a RC and corresponding Pods
    def set_rc_unique_label_key
      template[:spec][:uniqueLabelKey] = CUSTOM_UNIQUE_LABEL_KEY
    end

    def set_replica_target
      template[:spec][:replicas] = @doc.replica_target
    end

    def set_name
      template[:metadata][:name] = @doc.kubernetes_role.resource_name
    end

    # Sets the labels for each new Pod.
    # Adding the Release ID to allow us to track the progress of a new release from the UI.
    def set_spec_template_metadata
      release_doc_metadata.each do |key, value|
        pod_template[:metadata][:labels][key] ||= value.to_s
      end
    end

    # have to match Kubernetes::Release#clients selector
    # TODO: dry
    def release_doc_metadata
      @release_doc_metadata ||= begin
        release = @doc.kubernetes_release
        role = @doc.kubernetes_role
        deploy_group = @doc.deploy_group

        release.pod_selector(deploy_group).merge(
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
      container[:resources] = {
        limits: { cpu: @doc.cpu.to_f, memory: "#{@doc.ram}Mi" }
      }
    end

    def set_docker_image
      if @doc.build
        docker_path = @doc.build.docker_repo_digest ||
          "#{project.docker_repo(DockerRegistry.first)}:#{@doc.build.docker_tag}"
        # Assume first container is one we want to update docker image in
        container[:image] = docker_path
      end
    end

    def project
      @project ||= @doc.kubernetes_release.project
    end

    def env
      (container[:env] ||= [])
    end

    # custom annotation we support here and in kucodiff
    def missing_env
      required = ((annotations || {})[:"samson/required_env"] || "").strip.split(/[\s,]/)
      (required - env.map { |e| e.fetch(:name) }).presence
    end

    # helpful env vars, also useful for log tagging
    def set_env
      static_env.each { |k, v| env << {name: k.to_s, value: v.to_s} }

      # dynamic lookups for unknown things during deploy
      {
        POD_NAME: 'metadata.name',
        POD_NAMESPACE: 'metadata.namespace',
        POD_IP: 'status.podIP'
      }.each do |k, v|
        env << {
          name: k.to_s,
          valueFrom: {fieldRef: {fieldPath: v}}
        }
      end

      # unique, but keep last elements
      env.reverse!
      env.uniq! { |h| h[:name] }
      env.reverse!
    end

    def static_env
      env = {}

      metadata = release_doc_metadata
      [:REVISION, :TAG, :DEPLOY_ID, :DEPLOY_GROUP].each do |k|
        env[k] = metadata.fetch(k.downcase)
      end

      [:PROJECT, :ROLE].each do |k|
        env[k] = pod_template[:metadata][:labels][k.downcase]
      end

      # name of the cluster
      kube_cluster_name = DeployGroup.find(metadata[:deploy_group_id]).kubernetes_cluster.name.to_s
      env[:KUBERNETES_CLUSTER_NAME] = kube_cluster_name

      # env from plugins
      env.merge!(Samson::Hooks.fire(:deploy_group_env, project, @doc.deploy_group).inject({}, :merge!))
    end

    def set_vault_env
      if ENV["SECRET_STORAGE_BACKEND"] == "SecretStorage::HashicorpVault"
        containers.each do |container|
          (container[:env] ||= []).concat vault_env
        end
      end
    end

    def vault_env
      vault_client = Samson::Secrets::VaultClient.client.client(@doc.deploy_group)
      [
        {name: "VAULT_ADDR", value: vault_client.options.fetch(:address)},
        {name: "VAULT_SSL_VERIFY", value: vault_client.options.fetch(:ssl_verify).to_s}
      ]
    end

    # kubernetes needs docker secrets to be able to pull down images from the registry
    # in kubernetes 1.3 this might work without this workaround
    def set_image_pull_secrets
      client = @doc.deploy_group.kubernetes_cluster.client
      secrets = client.get_secrets(namespace: template.fetch(:metadata).fetch(:namespace))
      docker_credentials = secrets.
        select { |secret| secret.type == "kubernetes.io/dockercfg" }.
        map! { |c| {name: c.metadata.name} }

      return if docker_credentials.empty?

      pod_template.fetch(:spec, {})[:imagePullSecrets] = docker_credentials
    end

    def needs_secret_puller?
      SECRET_PULLER_IMAGE && secret_annotations.any?
    end

    def containers
      pod_template[:spec][:containers]
    end

    def container
      containers.first
    end
  end
end
