# frozen_string_literal: true
module Kubernetes
  class ResourceTemplate
    CUSTOM_UNIQUE_LABEL_KEY = 'rc_unique_identifier'
    SIDECAR_IMAGE = ENV['SECRET_SIDECAR_IMAGE'].presence

    def initialize(release_doc)
      @doc = release_doc
    end

    def to_hash
      @to_hash ||= begin
        set_rc_unique_label_key
        set_name
        set_namespace
        set_replica_target
        set_spec_template_metadata
        set_docker_image
        set_resource_usage
        set_secrets
        set_env
        set_image_pull_secrets

        hash = template
        Rails.logger.info "Created Kubernetes hash: #{hash.to_json}"
        hash
      end
    end

    def set_secrets
      return unless needs_secret_sidecar?
      set_secret_sidecar
      expand_secret_annotations
    end

    private

    def template
      @template ||= @doc.deploy_template
    end

    # look up keys in all possible namespaces by specificity
    def expand_secret_annotations
      resolver = Samson::Secrets::KeyResolver.new(project, [@doc.deploy_group])
      secret_annotations.each do |k, v|
        annotations.delete(k)
        resolver.expand(k, v).each { |k, v| annotations[k] = v }
      end
      resolver.verify!
    end

    def annotations
      template[:spec][:template][:metadata][:annotations]
    end

    def secret_annotations
      @secret_annotations ||= annotations.to_h.select do |annotation_name, _|
        annotation_name.to_s.start_with?(Samson::Secrets::HashicorpVaultBackend::VAULT_SECRET_BACKEND)
      end
    end

    # Sets up the secret_sidecar and the various mounts that are required
    # if the sidecar service is enabled
    # /vaultauth is a secrets volume in the cluster
    # /secretkeys are where the annotations from the config are mounted
    def set_secret_sidecar
      unless vault_config = VaultClient.client.config_for(@doc.deploy_group.vault_instance)
        raise "Could not find Vault config for #{@doc.deploy_group.permalink}"
      end

      containers.push(
        image: SIDECAR_IMAGE,
        name: 'secret-sidecar',
        volumeMounts: [
          { mountPath: "/vault-auth", name: "vaultauth" },
          { mountPath: "/secretkeys", name: "secretkeys" }
        ],
        env: [
          {name: :VAULT_ADDR, value: vault_config['vault_address'].to_s},
          {name: :VAULT_SSL_VERIFY, value: vault_config['tls_verify'].to_s}
        ]
      )

      # share secrets volume between all containers
      secret_vol = { mountPath: "/secrets", name: "secrets-volume" }
      containers.each do |container|
        (container[:volumeMounts] ||= []).push secret_vol
      end

      # define the shared volumes in the pod
      (template[:spec][:template][:spec][:volumes] ||= []).concat [
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

    # This key replaces the default kubernetes key: 'deployment.kubernetes.io/podTemplateHash'
    # This label is used by kubernetes to identify a RC and corresponding Pods
    def set_rc_unique_label_key
      template[:spec][:uniqueLabelKey] = CUSTOM_UNIQUE_LABEL_KEY
    end

    def set_replica_target
      template[:spec][:replicas] = @doc.replica_target if template[:kind] == 'Deployment'
    end

    def set_name
      template[:metadata][:name] = @doc.kubernetes_role.resource_name
    end

    def set_namespace
      template[:metadata][:namespace] = @doc.deploy_group.kubernetes_namespace
    end

    # Sets the labels for each new Pod.
    # Adding the Release ID to allow us to track the progress of a new release from the UI.
    def set_spec_template_metadata
      release_doc_metadata.each do |key, value|
        template[:spec][:template][:metadata][:labels][key] ||= value.to_s
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
        docker_path = @doc.build.docker_repo_digest || "#{project.docker_repo}:#{@doc.build.docker_ref}"
        # Assume first container is one we want to update docker image in
        container[:image] = docker_path
      end
    end

    def project
      @project ||= @doc.kubernetes_release.project
    end

    # helpful env vars, also useful for log tagging
    def set_env
      env = (container[:env] ||= [])

      static_env.each { |k, v| env << {name: k, value: v.to_s} }

      # dynamic lookups for unknown things during deploy
      {
        POD_NAME: 'metadata.name',
        POD_NAMESPACE: 'metadata.namespace',
        POD_IP: 'status.podIP'
      }.each do |k, v|
        env << {
         name: k,
         valueFrom: {fieldRef: {fieldPath: v}}
       }
      end
    end

    def static_env
      env = {}

      metadata = release_doc_metadata
      [:REVISION, :TAG, :DEPLOY_ID, :DEPLOY_GROUP].each do |k|
        env[k] = metadata.fetch(k.downcase)
      end

      [:PROJECT, :ROLE].each do |k|
        env[k] = template[:spec][:template][:metadata][:labels][k.downcase]
      end

      # name of the cluster
      kube_cluster_name = DeployGroup.find(metadata[:deploy_group_id]).kubernetes_cluster.name.to_s
      env[:KUBERNETES_CLUSTER_NAME] = kube_cluster_name

      # env from plugins
      env.merge!(Samson::Hooks.fire(:deploy_group_env, project, @doc.deploy_group).inject({}, :merge!))
    end

    # kubernetes needs docker secrets to be able to pull down images from the registry
    # in kubernetes 1.3 this might work without this workaround
    def set_image_pull_secrets
      secrets = @doc.client.get_secrets(namespace: @doc.namespace)
      docker_credentials = secrets.
        select { |secret| secret.type == "kubernetes.io/dockercfg" }.
        map! { |c| {name: c.metadata.name} }

      return if docker_credentials.empty?

      template[:spec].fetch(:template, {}).fetch(:spec, {})[:imagePullSecrets] = docker_credentials
    end

    def needs_secret_sidecar?
      SIDECAR_IMAGE && secret_annotations.any?
    end

    def containers
      template[:spec][:template][:spec][:containers]
    end

    def container
      containers.first
    end
  end
end
