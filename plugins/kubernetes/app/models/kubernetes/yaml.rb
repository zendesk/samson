module Kubernetes
  class Yaml
    def initialize(doc)
      @doc = doc
    end

    def to_hash
      @job_hash ||= begin
        set_namespace
        set_generate_name
        set_timeout
        set_job_labels
        set_docker_image
        # set_resource_usage
        set_secret_sidecar if ENV.fetch("SECRET_SIDECAR_IMAGE", false)
        set_env

        hash = template.to_hash
        Rails.logger.info "Created Kubernetes hash: #{hash.to_json}"
        hash
      end
    end

    def resource_name
      template[:kind].underscore
    end

    private

    def template
      @template ||= @doc.deploy_template
    end

    def set_namespace
      template[:metadata][:namespace] = @doc.deploy_group.kubernetes_namespace
    end

    def set_resource_usage
      container[:resources] = {
        limits: { cpu: @doc.cpu.to_f, memory: "#{@doc.ram}Mi" }
      }
    end

    def set_docker_image
      docker_path = @doc.build.docker_repo_digest || "#{@doc.build.project.docker_repo}:#{@doc.build.docker_ref}"
      # Assume first container is one we want to update docker image in
      container[:image] = docker_path
    end

    # helpful env vars, also useful for log tagging
    def set_env
      env = (container.env || [])

      [:REVISION, :TAG, :DEPLOY_GROUP, :PROJECT, :TASK].each do |k|
        env << {name: k, value: template.metadata.labels.send(k.downcase).to_s}
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
        containers = template[:spec].fetch(:template, {}).fetch(:spec, {}).fetch(:containers, [])
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
