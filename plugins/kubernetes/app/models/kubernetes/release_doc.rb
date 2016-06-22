module Kubernetes
  class ReleaseDoc < ActiveRecord::Base
    self.table_name = 'kubernetes_release_docs'

    belongs_to :kubernetes_role, class_name: 'Kubernetes::Role'
    belongs_to :kubernetes_release, class_name: 'Kubernetes::Release'
    belongs_to :deploy_group

    validates :deploy_group, presence: true
    validates :kubernetes_role, presence: true
    validates :kubernetes_release, presence: true
    validates :replica_target, presence: true, numericality: { greater_than: 0 }
    validate :validate_config_file, on: :create

    def build
      kubernetes_release.try(:build)
    end

    def client
      deploy_group.kubernetes_cluster.client
    end

    def job?
      deploy_yaml.resource_name == 'job'
    end

    def deploy
      case deploy_yaml.resource_name
      when 'deployment'
        deploy = Kubeclient::Deployment.new(deploy_yaml.to_hash)
        if deployed
          extension_client.update_deployment deploy
        else
          extension_client.create_deployment deploy
        end
      when 'daemon_set'
        daemon = Kubeclient::DaemonSet.new(deploy_yaml.to_hash)
        delete_daemon_set(daemon) if deployed
        extension_client.create_daemon_set daemon
      when 'job'
        # FYI per docs it is supposed to use batch api, but extension api works
        job = Kubeclient::Job.new(deploy_yaml.to_hash)
        if deployed
          extension_client.delete_job job.metadata.name, job.metadata.namespace
        end
        extension_client.create_job job
      else
        raise "Unknown deploy object #{deploy_yaml.resource_name}"
      end
    end

    def ensure_service
      if service.nil?
        'no Service defined'
      elsif service.running?
        'Service already running'
      else
        data = service_hash
        if data.fetch(:metadata).fetch(:name).include?(Kubernetes::Role::GENERATED)
          raise(
            Samson::Hooks::UserError,
            "Service name for role #{kubernetes_role.name} was generated and needs to be changed before deploying."
          )
        end
        client.create_service(Kubeclient::Service.new(data))
        'creating Service'
      end
    end

    def raw_template
      return @raw_template if defined?(@raw_template)
      @raw_template = kubernetes_release.project.repository.file_content(template_name, kubernetes_release.git_sha)
    end

    def template_name
      kubernetes_role.config_file
    end

    def deploy_template
      parsed_config_file.deploy || parsed_config_file.job
    end

    def desired_pod_count
      case deploy_yaml.resource_name
      when 'daemon_set'
        # need http request since we do not know how many nodes we will match
        deployed.status.desiredNumberScheduled
      when 'deployment', 'job' then replica_target
      else raise "Unsupported kind #{deploy_yaml.resource_name}"
      end
    end

    private

    # Create new client as 'Deployment' API is on different path then 'v1'
    def extension_client
      deploy_group.kubernetes_cluster.extension_client
    end

    def deploy_yaml
      @deploy_yaml ||= DeployYaml.new(self)
    end

    def deployed
      extension_client.send(
        "get_#{deploy_yaml.resource_name}",
        deploy_yaml.to_hash.fetch(:metadata).fetch(:name),
        deploy_group.kubernetes_namespace
      )
    rescue KubeException
      false
    end

    # we cannot replace or update a daemonset, so we take it down completely
    #
    # was do what `kubectl delete daemonset NAME` does:
    # - make it match no node
    # - waits for current to reach 0
    # - deletes the daemonset
    def delete_daemon_set(daemon_set)
      daemon_set_selector = [daemon_set.metadata.name, daemon_set.metadata.namespace]

      # make it match no node
      daemon_set = daemon_set.clone
      daemon_set.spec.template.spec.nodeSelector = {rand(9999).to_s => rand(9999).to_s}
      extension_client.update_daemon_set daemon_set

      # wait for it to terminate all it's pods
      loop do
        sleep 2
        current = extension_client.get_daemon_set(*daemon_set_selector)
        break if current.status.currentNumberScheduled == 0 && current.status.numberMisscheduled == 0
      end

      # delete it
      extension_client.delete_daemon_set *daemon_set_selector
    end

    def service
      return @service if defined?(@service)
      @service = if kubernetes_role.service_name.present?
        Kubernetes::Service.new(role: kubernetes_role, deploy_group: deploy_group)
      end
    end

    def service_hash
      @service_hash || begin
        hash = parsed_config_file.service(required: true)

        hash.fetch(:metadata)[:name] = kubernetes_role.service_name
        hash.fetch(:metadata)[:namespace] = namespace

        # For now, create a NodePort for each service, so we can expose any
        # apps running in the Kubernetes cluster to traffic outside the cluster.
        hash.fetch(:spec)[:type] = 'NodePort'

        hash
      end
    end

    def parsed_config_file
      @parsed_config_file ||= RoleConfigFile.new(raw_template, template_name)
    end

    def validate_config_file
      if build && kubernetes_role
        if raw_template.blank?
          errors.add(:kubernetes_release, "does not contain config file '#{template_name}'")
        elsif problems = RoleVerifier.new(raw_template).verify
          problems.each do |problem|
            errors.add(:kubernetes_release, "#{template_name}: #{problem}")
          end
        end
      end
    end

    def namespace
      deploy_group.kubernetes_namespace
    end
  end
end
