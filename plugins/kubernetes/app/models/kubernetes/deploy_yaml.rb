module Kubernetes
  class DeployYaml
    CUSTOM_UNIQUE_LABEL_KEY = 'rc_unique_identifier'.freeze
    DAEMON_SET = 'DaemonSet'.freeze
    DEPLOYMENT = 'Deployment'.freeze

    def initialize(release_doc)
      @doc = release_doc
    end

    def to_hash
      @deployment_hash ||= begin
        set_rc_unique_label_key
        set_namespace
        set_replica_target
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
        sections = YAML.load_stream(@doc.raw_template, @doc.template_name).
          select { |doc| [DEPLOYMENT, DAEMON_SET].include?(doc['kind']) }

        if sections.size == 1
          RecursiveOpenStruct.new(sections.first, recurse_over_arrays: true)
        else
          raise(
            Samson::Hooks::UserError,
            "Template #{@doc.template_name} has #{sections.size} Deployment sections, having 1 section is valid."
          )
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

    # Sets the labels for each new Pod.
    # Adding the Release ID to allow us to track the progress of a new release from the UI.
    def set_spec_template_metadata
      release_doc_metadata.each do |key, value|
        template.spec.template.metadata.labels[key] ||= value.to_s
      end
    end

    # have to match Kubernetes::Release#clients selector
    # TODO: dry
    def release_doc_metadata
      @release_doc_metadata ||= begin
        release = @doc.kubernetes_release
        role = @doc.kubernetes_role
        deploy_group = @doc.deploy_group
        build = @doc.build

        release.pod_selector(deploy_group).merge(
          deploy_id: release.deploy_id,
          project_id: release.project_id,
          role_id: role.id,
          deploy_group: deploy_group.env_value.parameterize,
          revision: build.git_sha,
          tag: build.git_ref.parameterize
        )
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

    # helpful env vars, also useful for log tagging
    def set_env
      env = (container.env || [])

      # static data
      metadata = release_doc_metadata
      [:REVISION, :TAG, :DEPLOY_ID, :DEPLOY_GROUP].each do |k|
        env << {name: k, value: metadata.fetch(k.downcase).to_s}
      end

      [:PROJECT, :ROLE].each do |k|
        env << {name: k, value: template.spec.template.metadata.labels.send(k.downcase).to_s}
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

      container.env = env
    end

    def container
      @container ||= begin
        containers = template.spec.template.try(:spec).try(:containers) || []
        if containers.empty?
          # TODO: support building and replacement for multiple containers
          raise(
            Samson::Hooks::UserError,
            "Template #{@doc.template_name} has #{containers.size} containers, having 1 section is valid."
          )
        end
        containers.first
      end
    end
  end
end
