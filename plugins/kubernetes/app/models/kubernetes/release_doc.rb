# frozen_string_literal: true
module Kubernetes
  class ReleaseDoc < ActiveRecord::Base
    self.table_name = 'kubernetes_release_docs'

    belongs_to :kubernetes_role, class_name: 'Kubernetes::Role'
    belongs_to :kubernetes_release, class_name: 'Kubernetes::Release'
    belongs_to :deploy_group

    serialize :resource_template, JSON

    validates :deploy_group, presence: true
    validates :kubernetes_role, presence: true
    validates :kubernetes_release, presence: true
    validate :validate_config_file, on: :create

    before_save :store_resource_template, on: :create

    attr_reader :previous_deploy

    def build
      kubernetes_release.try(:build)
    end

    def client
      deploy_group.kubernetes_cluster.client
    end

    def deployment?
      resource_kind == 'Deployment'
    end

    def daemon_set?
      resource_kind == 'DaemonSet'
    end

    def job?
      resource_kind == 'Job'
    end

    def valid_resource?
      deployment? || daemon_set? || job?
    end

    def deploy
      raise "Unknown deploy object #{resource_kind}" unless valid_resource?

      @deployed = true
      @previous_deploy = fetch_resource
      @new_deploy = if deployment?
        deploy = Kubeclient::Deployment.new(resource_template)
        if @previous_deploy
          extension_client.update_deployment deploy
        else
          extension_client.create_deployment deploy
        end
      elsif daemon_set?
        daemon = Kubeclient::DaemonSet.new(resource_template)
        delete_daemon_set(daemon) if @previous_deploy
        extension_client.create_daemon_set daemon
      elsif job?
        # FYI per docs it is supposed to use batch api, but extension api works
        job = Kubeclient::Job.new(resource_template)
        if @previous_deploy
          extension_client.delete_job resource_name, namespace
        end
        extension_client.create_job job
      end
    end

    def revert
      raise "Can only be done after a deploy" unless @deployed

      if deployment?
        if @previous_deploy
          extension_client.rollback_deployment(resource_name, namespace)
        else
          delete_deployment
        end
      elsif daemon_set?
        delete_daemon_set @new_deploy if @new_deploy
        extension_client.create_daemon_set(@previous_deploy) if @previous_deploy
      elsif job?
        extension_client.delete_job(resource_name, namespace)
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
      @desired_pod_count ||= begin
        if daemon_set?
          # need http request since we do not know how many nodes we will match
          fetch_resource.status.desiredNumberScheduled
        elsif deployment? || job?
          replica_target
        else
          raise "Unsupported kind #{resource_kind}"
        end
      end
    end

    def namespace
      deploy_group.kubernetes_namespace
    end

    private

    def resource_name
      kubernetes_role.resource_name
    end

    def resource_kind
      resource_template.fetch('kind')
    end

    def store_resource_template
      self.resource_template = ResourceTemplate.new(self)
    end

    # Create new client as 'Deployment' API is on different path then 'v1'
    def extension_client
      @extension_client ||= deploy_group.kubernetes_cluster.extension_client
    end

    def fetch_resource
      return nil unless valid_resource?

      extension_client.send(
        "get_#{resource_kind.underscore}",
        resource_name,
        namespace
      )
    rescue KubeException
      nil
    end

    def delete_deployment
      return unless deployed = fetch_resource
      copy = deployed.clone

      # Scale down the deployment to include zero pods
      copy.spec.replicas = 0
      extension_client.update_deployment copy

      # Wait for there to be zero pods
      loop do
        loop_sleep
        break if fetch_resource.status.replicas.to_i.zero?
      end

      # delete the actual deployment
      extension_client.delete_deployment resource_name, namespace
    end

    # we cannot replace or update a daemonset, so we take it down completely
    #
    # was do what `kubectl delete daemonset NAME` does:
    # - make it match no node
    # - waits for current to reach 0
    # - deletes the daemonset
    def delete_daemon_set(daemon_set)
      # make it match no node
      daemon_set = daemon_set.clone
      daemon_set.spec.template.spec.nodeSelector = {rand(9999).to_s => rand(9999).to_s}
      extension_client.update_daemon_set daemon_set

      # wait for it to terminate all it's pods
      max = 30
      (1..max).each do |i|
        loop_sleep
        current = fetch_resource
        scheduled = current.status.currentNumberScheduled
        misscheduled = current.status.numberMisscheduled
        break if scheduled.zero? && misscheduled.zero?
        if i == max
          raise(
            Samson::Hooks::UserError,
            "Unable to terminate previous DaemonSet, scheduled: #{scheduled} / misscheduled: #{misscheduled}\n"
          )
        end
      end

      # delete it
      extension_client.delete_daemon_set resource_name, namespace
    end

    def service
      return @service if defined?(@service)
      @service = if kubernetes_role.service_name.present?
        Kubernetes::Service.new(role: kubernetes_role, deploy_group: deploy_group)
      end
    end

    def service_hash
      @service_hash || begin
        hash = parsed_config_file.service ||
          raise(Samson::Hooks::UserError, "Unable to find Service definition in #{template_name}")

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
      return if !build || !kubernetes_role
      parsed_config_file
    rescue Samson::Hooks::UserError
      errors.add(:kubernetes_release, $!.message)
    end

    def loop_sleep
      sleep 2 unless ENV['RAILS_ENV'] == 'test'
    end
  end
end
