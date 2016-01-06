module Kubernetes
  module DeployYaml
    def deployment_hash
      @deployment_yaml ||=
        if replication_controller_doc.present?
          JSON.parse(replication_controller_doc).with_indifferent_access
        else
          template.spec.replicas = replica_target
          template.metadata.namespace = deploy_group.kubernetes_namespace
          add_labels
          update_docker_image
          set_resource_usage
          Rails.logger.info "Created K8S hash: #{template}"
          template
        end
    end

    private

    def template
      @template ||= begin
        yaml = YAML.load_stream(raw_template, kubernetes_role.config_file).detect do |doc|
          doc['kind'] == 'ReplicationController' || doc['kind'] == 'Deployment'
        end
        RecursiveOpenStruct.new(yaml, :recurse_over_arrays => true)
      end
    end

    def raw_template
      @raw_template ||= build.file_from_repo(kubernetes_role.config_file)
    end

    def add_labels
      labels.each do |key, value|
        template.metadata.labels[key] = value
        template.spec.selector[key] = value
        template.spec.template.metadata.labels[key] = value
      end
    end

    def set_resource_usage
      container.resources = {
        limits: { cpu: kubernetes_role.cpu, memory: kubernetes_role.ram_with_units }
      }
    end

    def labels
      kubernetes_release.pod_labels.merge(role: kubernetes_role.label_name, role_id: kubernetes_role.id.to_s)
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
