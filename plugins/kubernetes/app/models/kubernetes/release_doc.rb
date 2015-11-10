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
    validates :replicas_live, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :status, presence: true, inclusion: Kubernetes::Release::STATUSES
    validate :validate_config_file, on: :create

    after_create :save_rc_info    # do this after create, so id has been generated

    Kubernetes::Release::STATUSES.each do |s|
      define_method("#{s}?") { status == s }
    end

    # Definition of the ReplicationController, based on the rc_template, but
    # updated with the image and metadata for this deploy.
    #
    # This hash can be passed to the Kubernetes API to create a ReplicationController.
    def rc_hash
      return @rc_hash if defined?(@rc_hash)

      if replication_controller_doc.present?
        @rc_hash = JSON.parse(replication_controller_doc).with_indifferent_access
      else
        build_rc_hash
      end
    end

    # The raw template defining the ReplicationController, taken from the config
    # file in the project's repo.
    def rc_template
      @rc_template ||= begin
        # It's possible for the file to contain more than one definition,
        # like a ReplicationController and a Service.
        Array.wrap(parsed_config_file).detect { |doc| doc['kind'] == 'ReplicationController' }.freeze
      end
    end

    def has_service?
      kubernetes_role.has_service? && service_template.present?
    end

    def service_hash
      @service_hash || (build_service_hash if has_service?)
    end

    def service_template
      @service_template ||= begin
        # It's possible for the file to contain more than one definition,
        # like a ReplicationController and a Service.
        hash = Array.wrap(parsed_config_file).detect { |doc| doc['kind'] == 'Service' }
        (hash || {}).freeze
      end
    end

    def service
      kubernetes_role.service_for(deploy_group) if has_service?
    end

    def pretty_rc_doc(format: :json)
      case format
        when :json
          JSON.pretty_generate(rc_hash)
        when :yaml, :yml
          rc_hash.to_yaml
        else
          rc_hash.to_s
      end
    end

    def build
      kubernetes_release.try(:build)
    end

    # These labels will be attached to the Pod and the ReplicationController
    def pod_labels
      kubernetes_release.pod_labels.merge(role: kubernetes_role.label_name)
    end

    def nested_error_messages
      errors.full_messages
    end

    def watch_controller(&block)
      @watcher = Watchers::ReplicationControllerWatcher.new(client, namespace,
                                                            name: replication_controller_name,
                                                            log: true)
      @watcher.start_watching(&block)
    end

    def stop_watching
      @watcher.stop_watching if @watcher
    end

    def update_replica_count(new_count)
      self.replicas_live = new_count

      if replicas_live >= replica_target
        self.status ='live'
      elsif replicas_live > 0
        self.status ='spinning_up'
      end
    end

    def client
      deploy_group.kubernetes_cluster.client
    end

    private

    def save_rc_info
      build_rc_hash

      # Create a unique name for the ReplicationController, that won't collide
      # with other RCs.  We do this by appending the id of the ReleaseDoc, so
      # they will be different for each of the Roles deployed for this Build.
      rc_name = @rc_hash[:metadata][:name] || "#{build.project_name}-#{kubernetes_role.label_name}"
      self.replication_controller_name = "#{rc_name}-#{id}"
      @rc_hash[:metadata][:name] = replication_controller_name

      self.replication_controller_doc = @rc_hash.to_json

      save!
    end

    def build_rc_hash
      @rc_hash = rc_template.dup.with_indifferent_access
      @rc_hash[:spec][:replicas] = replica_target

      pod_hash = @rc_hash[:spec][:template]

      # Add the identifier of this particular build to the metadata
      pod_hash[:metadata][:labels].merge!(pod_labels)
      @rc_hash[:metadata][:labels].merge!(pod_labels)
      @rc_hash[:spec][:selector].merge!(pod_labels)

      @rc_hash[:metadata][:namespace] = namespace

      # Set the Docker image to be deployed in the pod.
      # NOTE: This logic assumes that if there are multiple containers defined
      # in the pod, the container that should run the image from this project
      # is the first container defined.
      container_hash = pod_hash[:spec][:containers].first
      container_hash[:image] = build.docker_repo_digest

      container_hash[:resources] = {
        limits: { cpu: kubernetes_role.cpu, memory: kubernetes_role.ram_with_units }
      }

      @rc_hash
    end

    def build_service_hash
      @service_hash = service_template.dup.with_indifferent_access

      @service_hash[:metadata][:name] = kubernetes_role.service_name
      @service_hash[:metadata][:namespace] = namespace
      @service_hash[:metadata][:labels] ||= pod_labels.except(:release_id)

      # For now, create a NodePort for each service, so we can expose any
      # apps running in the Kubernetes cluster to traffic outside the cluster.
      @service_hash[:spec][:type] = 'NodePort'

      @service_hash
    end

    def parsed_config_file
      Kubernetes::Util.parse_file(config_template, kubernetes_role.config_file)
    end

    def config_template
      @config_template ||= build.file_from_repo(kubernetes_role.config_file)
    end

    def validate_config_file
      if build && kubernetes_role && config_template.blank?
        errors.add(:build, "does not contain config file '#{kubernetes_role.config_file}'")
      end
    end

    def env_as_list
      env = EnvironmentVariable.env(build.project, deploy_group)
      env.each_with_object([]) do |(k,v), list|
        list << { name: k, value: v.to_s }
      end
    end

    def namespace
      deploy_group.kubernetes_namespace
    end
  end
end
