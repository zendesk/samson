module Kubernetes
  class DeployYaml
    CUSTOM_UNIQUE_LABEL_KEY = 'rc_unique_identifier'
    DAEMON_SET = 'DaemonSet'
    DEPLOYMENT = 'Deployment'

    def initialize(release_doc)
      @doc = release_doc
    end

    def to_hash
      @deployment_hash ||= begin
        set_rc_unique_label_key
        set_namespace
        set_replica_target
        set_deployment_metadata
        set_selector_metadata
        set_spec_template_metadata
        set_docker_image
        set_resource_usage
        set_env

        hash = template.to_hash
        Rails.logger.info "Created Kubernetes hash: #{hash.to_json}"
        hash
      end
    end

    def resource_name
      template.kind.underscore
    end

    private

    def template
      @template ||= begin
        sections = YAML.load_stream(@doc.raw_template, @doc.template_name).select { |doc| [DEPLOYMENT, DAEMON_SET].include?(doc['kind']) }
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
      template.spec.replicas = @doc.replica_target if template.kind == DEPLOYMENT
    end

    def set_namespace
      template.metadata.namespace = @doc.deploy_group.kubernetes_namespace
    end

    # Sets the labels for the Deployment resource metadata
    # only supports strings or we run into `json: expect char '"' but got char '2'`
    def set_deployment_metadata
      template.metadata.labels ||= {}
      deployment_labels.each do |key, value|
        template.metadata.labels[key] = value.to_s
      end
    end

    # labels that are used to match the previous replicasets,
    # they cannot change or we will create a new replicasets instead of updating the previous one
    # renaming roles or renaming projects will lead to duplicate replicasets
    def deployment_labels
      release_doc_metadata.slice(:project, :role)
    end

    # Sets the metadata that is going to be used as the selector. Kubernetes will use this metadata to select the
    # old and new Replication Controllers when managing a new Deployment.
    def set_selector_metadata
      template.spec.selector ||= {}
      template.spec.selector.matchLabels ||= {}

      deployment_labels.each do |key, value|
        template.spec.selector.matchLabels[key] = value.to_s
      end
    end

    # Sets the labels for each new Pod.
    # Adding the Release ID to allow us to track the progress of a new release from the UI.
    def set_spec_template_metadata
      release_doc_metadata.each do |key, value|
        template.spec.template.metadata.labels[key] = value.to_s
      end
    end

    def release_doc_metadata
      @release_doc_metadata ||= begin
        release = @doc.kubernetes_release
        role = @doc.kubernetes_role
        deploy_group = @doc.deploy_group
        build = @doc.build
        {
          release_id: release.id,
          deploy_id: release.deploy_id,
          project: release.project.permalink,
          project_id: release.project_id,

          role: role.name.parameterize,
          role_id: role.id,

          deploy_group: deploy_group.env_value.parameterize,
          deploy_group_id: deploy_group.id,

          revision: build.git_sha,
          tag: build.git_ref.parameterize
        }
      end
    end

    def set_resource_usage
      container.resources = {
        limits: { cpu: @doc.cpu.to_f, memory: "#{@doc.ram}Mi" }
      }
    end

    def set_docker_image
      docker_path = @doc.build.docker_repo_digest || "#{@doc.build.project.docker_repo}:#{@doc.build.docker_ref}"
      # Assume first container is one we want to update docker image in
      container.image = docker_path
    end

    def set_env
      env = (container.env || [])

      # static data
      metadata = release_doc_metadata
      [:REVISION, :TAG, :PROJECT, :ROLE, :DEPLOY_ID, :DEPLOY_GROUP].each do |k|
        env << {name: k, value: metadata.fetch(k.downcase).to_s}
      end

      # dynamic lookups for unknown things during deploy
      {
        POD_NAME: 'metadata.name',
        POD_NAMESPACE: 'metadata.namespace',
        POD_IP: 'status.podIP'
      }.each do |k,v|
         env << {
          name: k,
          valueFrom: {fieldRef: {fieldPath: v}}
        }
      end

      container.env = env
    end

    def container
      @container ||= begin
        containers = template.spec.template.try(:spec).try(:containers) || []
        if containers.size == 0
          # TODO: support building and replacement for multiple containers
          raise Samson::Hooks::UserError, "Template #{@doc.template_name} has #{containers.size} containers, having 1 section is valid."
        end
        containers.first
      end
    end
  end
end
