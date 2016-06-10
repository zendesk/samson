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

    # used via deprecated release flow
    def fail!
      update_attribute(:status, :failed)
    end

    def build
      kubernetes_release.try(:build)
    end

    # used via deprecated release flow
    def update_release
      kubernetes_release.update_status(self)
    end

    # used via deprecated release flow
    def update_status(live_pods)
      if live_pods == replica_target then self.status = :live
      elsif live_pods.zero? then self.status = :dead
      elsif live_pods > replicas_live then self.status = :spinning_up
      elsif live_pods < replicas_live then self.status = :spinning_down
      end
      save!
    end

    # used via deprecated release flow
    def update_replica_count(new_count)
      update_attributes!(replicas_live: new_count)
    end

    # used via deprecated release flow
    def live_replicas_changed?(new_count)
      new_count != replicas_live
    end

    # used via deprecated release flow
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
        if deployed
          extension_client.update_deployment deploy
        else
          extension_client.create_deployment deploy
        end
      when 'daemon_set'
        daemon = Kubeclient::DaemonSet.new(deploy_yaml.to_hash)
        delete_daemon_set(daemon) if deployed
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

    def deploy_template
      self.class.deploy_template(raw_template, template_name)
    end

    def self.deploy_template(raw_template, template_name)
      sections = parse_config_file(raw_template, template_name).
        select { |doc| ['Deployment', 'DaemonSet'].include?(doc.fetch('kind')) }

      if sections.size == 1
        sections.first.with_indifferent_access
      else
        raise(
          Samson::Hooks::UserError,
          "Template #{template_name} has #{sections.size} Deployment sections, having 1 section is valid."
        )
      end
    end

    def self.parse_config_file(raw_template, template_name)
      Array.wrap(Kubernetes::Util.parse_file(raw_template, template_name))
    end

    def desired_pod_count
      case deploy_yaml.resource_name
      when 'daemon_set'
        # need http request since we do not know how many nodes we will match
        deployed.status.desiredNumberScheduled
      when 'deployment' then replica_target
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
      self.class.parse_config_file(raw_template, template_name)
    end

    def validate_config_file
      if build && kubernetes_role
        if raw_template.blank?
          errors.add(:build, "does not contain config file '#{template_name}'")
        elsif problems = RoleVerifier.new(raw_template).verify
          problems.each do |problem|
            errors.add(:build, "#{template_name}: #{problem}")
          end
        end
      end
    end

    def namespace
      deploy_group.kubernetes_namespace
    end
  end
end
