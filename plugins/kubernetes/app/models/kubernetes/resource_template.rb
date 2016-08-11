# frozen_string_literal: true
module Kubernetes
  class ResourceTemplate
    CUSTOM_UNIQUE_LABEL_KEY = 'rc_unique_identifier'
    SIDECAR_NAME = 'secret-sidecar'
    SIDECAR_IMAGE = ENV['SECRET_SIDECAR_IMAGE'].presence

    class SecretKeyResolver
      def initialize(project, deploy_groups)
        @project = project
        @deploy_groups = deploy_groups
        @errors = []
      end

      # expands a key by finding the most specific value for it
      # bar -> production/my_project/pod100/bar
      def expand!(secret_key)
        key = secret_key.split('/', 2).last

        # build a list of all possible ids
        possible_ids = possible_secret_key_parts.map do |id|
          SecretStorage.generate_secret_key(id.merge(key: key))
        end

        # use the value of the first id that exists
        all_found = SecretStorage.read_multi(possible_ids)

        if found = possible_ids.detect { |id| all_found[id] }
          secret_key.replace(found)
        else
          @errors << "#{secret_key} (tried: #{possible_ids.join(', ')})"
          nil
        end
      end

      # raises all errors at once for faster debugging
      def verify!
        if @errors.any?
          raise(
            Samson::Hooks::UserError,
            "Failed to resolve secret keys:\n\t#{@errors.join("\n\t")}"
          )
        end
      end

      private

      def possible_secret_key_parts
        @possible_secret_key_parts ||= begin
          environments = @deploy_groups.map(&:environment).uniq

          # build list of allowed key parts
          environment_permalinks = ['global']
          project_permalinks = ['global']
          deploy_group_permalinks = ['global']

          environment_permalinks.concat(environments.map(&:permalink)) if environments.size == 1
          project_permalinks << @project.permalink if @project
          deploy_group_permalinks.concat(@deploy_groups.map(&:permalink)) if @deploy_groups.size == 1

          # build a list of all key part combinations, sorted by most specific
          deploy_group_permalinks.reverse_each.flat_map do |d|
            project_permalinks.reverse_each.flat_map do |p|
              environment_permalinks.reverse_each.map do |e|
                {
                  deploy_group_permalink: d,
                  project_permalink: p,
                  environment_permalink: e,
                }
              end
            end
          end
        end
      end
    end

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

    # look up keys in all possible namespaces by specificity
    #
    # deprecated: expand $ENV and $DEPLOY_GROUP in annotation that start with 'secret/'
    # TODO: use this in terminal_executor too see https://github.com/zendesk/samson/pull/1022
    def expand_secret_annotations
      resolver = SecretKeyResolver.new(@doc.build.project, [@doc.deploy_group])
      secret_annotations.each_value { |secret_key| resolver.expand!(secret_key) }
      resolver.verify!
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
