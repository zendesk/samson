module Kubernetes
  class ResourceTemplate
    CUSTOM_UNIQUE_LABEL_KEY = 'rc_unique_identifier'.freeze
    SIDECAR_NAME = 'secret-sidecar'.freeze
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
        if needs_secret_sidecar?
          set_secret_sidecar
          expand_secret_annotations
          verify_secret_annotations
        end
        set_env

        hash = template
        Rails.logger.info "Created Kubernetes hash: #{hash.to_json}"
        hash
      end
    end

    private

    def template
      @template ||= @doc.deploy_template
    end

    # expand $ENV and $DEPLOY_GROUP in annotation that start with 'secret/'
    def expand_secret_annotations
      secret_annotations.each do |_, secret_key|
        secret_key.gsub!(/\${ENV}/, @doc.deploy_group.environment.permalink)
        secret_key.gsub!(/\${DEPLOY_GROUP}/, @doc.deploy_group.permalink)
      end
    end

    # verify that each secret really exists and inform the user
    # if it does not as the deployment will fail
    def verify_secret_annotations
      errors = []
      secret_annotations.each do |annotation_name, secret_key|
        begin
          SecretStorage.read(secret_key)
        rescue ActiveRecord::RecordNotFound, NoMethodError
          errors << "Secret #{annotation_name} with key #{secret_key} could not be found."
        end
      end
      if errors.any?
        raise(
          Samson::Hooks::UserError,
          "Missing Secret Keys:\n\t#{errors.join("\n\t")}"
        )
      end
    end

    def annotations
      @template[:spec][:template][:metadata][:annotations]
    end

    def secret_annotations
      @secret_annotations ||= annotations.to_h.select do |annotation_name, _|
        annotation_name.to_s.start_with?(SecretStorage::VAULT_SECRET_BACKEND)
      end
    end

    # Sets up the secret_sidecar and the various mounts that are required
    # if the sidecar service is enabled
    # /vaultauth is a secrets volume in the cluster
    # /secretkeys are where the annotations from the config are mounted
    def set_secret_sidecar
      pod_volumes =
        [
          {name: "secrets-volume", emptyDir: {}},
          {name: "vaultauth", secret: {secretName: "vaultauth"}},
          {
            name: "secretkeys",
            downwardAPI:
            {
              items: [{path: "annotations", fieldRef: {fieldPath: "metadata.annotations"}}]
            }
          }
        ]
      secret_vol = { mountPath: "/secrets", name: "secrets-volume" }
      secret_sidecar = {
        image: SIDECAR_IMAGE,
        name: SIDECAR_NAME,
        volumeMounts: [
          secret_vol,
          { mountPath: "/vault-auth", name: "vaultauth" },
          { mountPath: "/secretkeys", name: "secretkeys" }
        ]
      }

      containers = template[:spec][:template][:spec][:containers]

      # inject the secrets FS into the primary container to share the secrets
      container = containers.first
      (container[:volumeMounts] ||= []).push secret_vol

      # add the sidcar container
      containers.push secret_sidecar

      # define the shared volumes in the pod
      (template[:spec][:template][:spec][:volumes] ||= []).concat pod_volumes
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
        docker_path = @doc.build.docker_repo_digest || "#{@doc.build.project.docker_repo}:#{@doc.build.docker_ref}"
        # Assume first container is one we want to update docker image in
        container[:image] = docker_path
      end
    end

    # helpful env vars, also useful for log tagging
    def set_env
      env = (container[:env] ||= [])

      # static data
      metadata = release_doc_metadata
      [:REVISION, :TAG, :DEPLOY_ID, :DEPLOY_GROUP].each do |k|
        env << {name: k, value: metadata.fetch(k.downcase).to_s}
      end

      [:PROJECT, :ROLE].each do |k|
        env << {name: k, value: template[:spec][:template][:metadata][:labels][k.downcase].to_s}
      end

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

      if needs_secret_sidecar?
        vault_config = VaultClient.client.config_for(@doc.deploy_group.vault_instance)
        raise StandardError, "Could not find Vault config for #{@doc.deploy_group.permalink}" unless vault_config

        sidecar_env = (sidecar_container[:env] ||= [])
        {
          VAULT_ADDR: vault_config['vault_address'],
          VAULT_SSL_VERIFY: vault_config['tls_verify']
        }.each do |k, v|
          sidecar_env << {
            name: k,
            value: v.to_s
          }
        end
      end
    end

    def needs_secret_sidecar?
      SIDECAR_IMAGE && secret_annotations.any?
    end

    def container
      @container ||= begin
        template[:spec].fetch(:template, {}).fetch(:spec, {}).fetch(:containers, []).first
      end
    end

    def sidecar_container
      @sidecar ||= begin
        template[:spec][:template][:spec][:containers].detect do |possible_container|
          break possible_container if possible_container[:name] == SIDECAR_NAME
        end
      end
    end
  end
end
