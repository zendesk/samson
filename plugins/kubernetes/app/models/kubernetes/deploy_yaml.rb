module Kubernetes
  class DeployYaml
    CUSTOM_UNIQUE_LABEL_KEY = 'rc_unique_identifier'

    def initialize(release_doc)
      @doc = release_doc
    end

    def deployment_hash
      deployment_spec.to_hash
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
      Rails.logger.info "Created Kubernetes hash: #{template.to_hash}"
      template
    end

    def template
      @template ||= begin
        sections = YAML.load_stream(@doc.raw_template, @doc.template_name).select { |doc| doc['kind'] == 'Deployment' }
        if sections.size == 1
          RecursiveOpenStruct.new(sections.first, recurse_over_arrays: true)
        else
          raise Samson::Hooks::UserError, "Template #{@doc.template_name} has #{sections.size} Deployment sections, having 1 section is valid."
        end
      end
    end

    # This key replaces the default kubernetes key: 'deployment.kubernetes.io/podTemplateHash'
    # This label is used by kubernetes to identify a RC and corresponding Pods
    def set_rc_unique_label_key
      template.spec.uniqueLabelKey = CUSTOM_UNIQUE_LABEL_KEY
    end

    def set_replica_target
      template.spec.replicas = @doc.replica_target
    end

    def set_namespace
      template.metadata.namespace = @doc.deploy_group.kubernetes_namespace
    end

    # Sets the labels for the Deployment resource metadata
    # only supports strings or we run into `json: expect char '"' but got char '2'`
    def set_deployment_metadata
      deployment_labels.each do |key, value|
        template.metadata.labels[key] = value.to_s
      end
    end

    def deployment_labels
      # Deployment labels should not include the ids of the release, role or deploy groups
      release_doc_metadata.except(:release_id, :role_id, :deploy_group_id)
    end

    # Sets the metadata that is going to be used as the selector. Kubernetes will use this metadata to select the
    # old and new Replication Controllers when managing a new Deployment.
    def set_selector_metadata
      if !template.spec.selector || !template.spec.selector.matchLabels
        raise Samson::Hooks::UserError, "Missing spec.selector.matchLabels"
      end
      deployment_labels.each do |key, value|
        template.spec.selector.matchLabels[key] = value.to_s
      end
    end

    # Sets the labels for each new Pod.
    # Appending the Release ID to allow us to track the progress of a new release from the UI.
    def set_spec_template_metadata
      release_doc_metadata.each do |key, value|
        template.spec.template.metadata.labels[key] = value.to_s
      end
    end

    def release_doc_metadata
      release_metadata.merge(role_metadata).merge(deploy_group_metadata)
    end

    def release_metadata
      release = @doc.kubernetes_release
      {
        release_id: release.id,
        project_id: release.project_id
      }
    end

    def role_metadata
      { role_id: @doc.kubernetes_role.id, role_name: @doc.kubernetes_role.name }
    end

    def deploy_group_metadata
      { deploy_group_id: @doc.deploy_group.id, deploy_group_namespace: @doc.deploy_group.kubernetes_namespace }
    end

    def set_resource_usage
      container.resources = {
        limits: { cpu: @doc.cpu.to_f, memory: "#{@doc.ram}Mi" }
      }
    end

    def update_docker_image
      docker_path = @doc.build.docker_repo_digest || "#{@doc.build.project.docker_repo}:#{@doc.build.docker_ref}"
      # Assume first container is one we want to update docker image in
      container.image = docker_path
    end

    def container
      containers = template.spec.template.try(:spec).try(:containers) || []
      if containers.size != 1
        raise Samson::Hooks::UserError, "Template #{@doc.template_name} has #{containers.size} containers, having 1 section is valid."
      end
      containers.first
    end
  end
end
