module Kubernetes
  class ReleaseDoc < ActiveRecord::Base
    include Kubernetes::HasStatus

    self.table_name = 'kubernetes_release_docs'

    belongs_to :kubernetes_role, class_name: 'Kubernetes::Role'
    belongs_to :kubernetes_release, class_name: 'Kubernetes::Release'
    belongs_to :deploy_group

    validates :deploy_group, presence: true
    validates :kubernetes_role, presence: true
    validates :kubernetes_release, presence: true
    validates :replica_target, presence: true, numericality: { greater_than: 0 }
    validates :replicas_live, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :status, presence: true, inclusion: STATUSES
    validate :validate_config_file, on: :create

    def fail!
      update_attribute(:status, :failed)
    end

    def build
      kubernetes_release.try(:build)
    end

    def update_release
      kubernetes_release.update_status(self)
    end

    def update_status(live_pods)
      if live_pods == replica_target then self.status = :live
      elsif live_pods.zero? then self.status = :dead
      elsif live_pods > replicas_live then self.status = :spinning_up
      elsif live_pods < replicas_live then self.status = :spinning_down
      end
      save!
    end

    def update_replica_count(new_count)
      update_attributes!(replicas_live: new_count)
    end

    def live_replicas_changed?(new_count)
      new_count != replicas_live
    end

    def recovered?(failed_pods)
      failed_pods == 0
    end

    def client
      deploy_group.kubernetes_cluster.client
    end

    def deploy
      case deploy_yaml.resource_name
      when 'deployment'
        deploy = Kubeclient::Deployment.new(deploy_yaml.to_hash)
        if resource_running?(deploy)
          extension_client.update_deployment deploy
        else
          extension_client.create_deployment deploy
        end
      when 'daemon_set'
        daemon = Kubeclient::DaemonSet.new(deploy_yaml.to_hash)
        delete_daemon_set(daemon) if resource_running?(daemon)
        extension_client.create_daemon_set daemon
      else raise "Unknown daemon_set #{deploy_yaml.resource_name}"
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
      @raw_template ||= build.file_from_repo(template_name)
    end

    def template_name
      kubernetes_role.config_file
    end

    private

    # Create new client as 'Deployment' API is on different path then 'v1'
    def extension_client
      deploy_group.kubernetes_cluster.extension_client
    end

    def deploy_yaml
      @deploy_yaml ||= DeployYaml.new(self)
    end

    def resource_running?(resource)
      extension_client.send("get_#{deploy_yaml.resource_name}", resource.metadata.name, resource.metadata.namespace)
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
      if kubernetes_role.service_name.present?
        Kubernetes::Service.new(role: kubernetes_role, deploy_group: deploy_group)
      end
    end

    def service_hash
      @service_hash || begin
        hash = service_template

        hash.fetch(:metadata)[:name] = kubernetes_role.service_name
        hash.fetch(:metadata)[:namespace] = namespace

        # For now, create a NodePort for each service, so we can expose any
        # apps running in the Kubernetes cluster to traffic outside the cluster.
        hash.fetch(:spec)[:type] = 'NodePort'

        hash
      end
    end

    # Config has multiple entries like a ReplicationController and a Service
    def service_template
      services = parsed_config_file.select { |doc| doc['kind'] == 'Service' }
      unless services.size == 1
        raise(
          Samson::Hooks::UserError,
          "Template #{template_name} has #{services.size} services, having 1 section is valid."
        )
      end
      services.first.with_indifferent_access
    end

    def parsed_config_file
      Array.wrap(Kubernetes::Util.parse_file(raw_template, template_name))
    end

    def validate_config_file
      if build && kubernetes_role
        if raw_template.blank?
          errors.add(:build, "does not contain config file '#{template_name}'")
        elsif !project_and_role_consistent?
          errors.add(:build, "config file '#{template_name}' does not have consistent project and role labels")
        end
      end
    end

    def project_and_role_consistent?
      labels = parsed_config_file.flat_map do |resource|
        kind = resource.fetch('kind')

        label_paths =
          case kind
          when 'Service'
            [['spec', 'selector']]
          when 'Deployment', 'DaemonSet'
            [
              ['spec', 'template', 'metadata', 'labels'],
              ['spec', 'selector', 'matchLabels'],
            ]
          else
            [] # ignore unknown / unsupported types
          end

        label_paths.map do |path|
          path.inject(resource) { |r, k| r[k] || {} }.slice('project', 'role')
        end
      end

      labels = labels.uniq
      labels.size == 1 && labels.first.size == 2
    end

    def namespace
      deploy_group.kubernetes_namespace
    end
  end
end
