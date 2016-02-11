module Kubernetes
  module DeployYaml
    CUSTOM_UNIQUE_LABEL_KEY = 'rc_unique_identifier'

    def deployment_hash
      @deployment_hash ||= deployment_spec.to_hash
    end

    private

    def deployment_spec
      set_rc_unique_label_key
      set_namespace
      set_replica_target
      set_deployment_metadata
      set_selector_metadata
      set_spec_template_metadata
      update_docker_image
      set_resource_usage
      Rails.logger.info "Created K8S hash: #{template.to_hash}"
      template
    end

    def template
      @template ||= begin
        yaml = YAML.load_stream(raw_template, kubernetes_role.config_file).detect do |doc|
          doc['kind'] == 'Deployment'
        end
        RecursiveOpenStruct.new(yaml, :recurse_over_arrays => true)
      end
    end

    def raw_template
      @raw_template ||= build.file_from_repo(kubernetes_role.config_file)
    end

    # This key replaces the default kubernetes key: 'deployment.kubernetes.io/podTemplateHash'
    # This label is used by kubernetes to identify a RC and corresponding Pods
    def set_rc_unique_label_key
      template.spec.uniqueLabelKey = CUSTOM_UNIQUE_LABEL_KEY
    end

    def set_replica_target
      template.spec.replicas = replica_target
    end

    def set_namespace
      template.metadata.namespace = deploy_group.kubernetes_namespace
    end

    # Sets the labels for the Deployment resource metadata
    def set_deployment_metadata
      deployment_labels.each do |key, value|
        template.metadata.labels[key] = value
      end
    end

    def deployment_labels
      # Deployment labels should not include the ids of the release, role or deploy groups
      release_doc_metadata.except(:release_id, :role_id, :deploy_group_id)
    end

    # Sets the metadata that is going to be used as the selector. Kubernetes will use this metadata to select the
    # old and new Replication Controllers when managing a new Deployment.
    def set_selector_metadata
      deployment_labels.each do |key, value|
        template.spec.selector[key] = value
      end
    end

    # Sets the labels for each new Pod.
    # Appending the Release ID to allow us to track the progress of a new release from the UI.
    def set_spec_template_metadata
      release_doc_metadata.each do |key, value|
        template.spec.template.metadata.labels[key] = value
      end
    end

    def set_resource_usage
      container.resources = {
        limits: { cpu: kubernetes_role.cpu, memory: kubernetes_role.ram_with_units }
      }
    end

    def update_docker_image
      docker_path = build.docker_repo_digest || "#{build.project.docker_repo}:#{build.docker_ref}"
      # Assume first container is one we want to update docker image in
      container.image = docker_path
    end

    def container
      template.spec.template.spec.containers.first
    end
  end
end
