module Kubernetes

  # This file represents a Kubernetes configuration file for a specific project role.
  # A single configuration file can have both a Replication Controller and a Service, as two separate documents.
  #
  # For the schema definition of a Replication Controller see:
  # https://cloud.google.com/container-engine/docs/replicationcontrollers/operations
  #
  # For the schema definition of a Service, see:
  # https://cloud.google.com/container-engine/docs/services/operations
  #
  class RoleConfigFile
    attr_reader :file_path, :replication_controller, :service

    def initialize(contents, file_path)
      @file_path = file_path
      @config_file = Kubernetes::Util.parse_file(contents, file_path)
      parse_file
    end

    private

    def parse_file
      parse_replication_controller
      parse_service
    end

    def parse_replication_controller
      rc_hash = as_hash('ReplicationController')
      raise 'ReplicationController missing in the configuration file.' if rc_hash.nil?
      @replication_controller = ReplicationController.new(rc_hash)
    end

    def parse_service
      service_hash = as_hash('Service')
      @service = Service.new(service_hash) unless service_hash.nil?
    end

    def as_hash(type)
      hash = Array.wrap(@config_file).detect { |doc| doc['kind'] == type }.freeze
      hash.dup.with_indifferent_access unless hash.nil?
    end

    #
    # INNER CLASSES
    #

    class ReplicationController

      def initialize(rc_hash)
        @rc_hash = rc_hash
      end

      def labels
        metadata[:labels]
      end

      def replicas
        spec[:replicas]
      end

      def selector
        spec[:selector]
      end

      def pod_template
        @pod_template ||= PodTemplate.new(spec[:template])
      end

      def deploy_strategy
        'rolling_update' #TODO: NOT SUPPORTED THROUGH YAML FILE YET ?
      end

      private

      def metadata
        @rc_hash[:metadata]
      end

      def spec
        @rc_hash[:spec]
      end
    end

    class PodTemplate

      def initialize(pod_hash)
        @pod_hash = pod_hash
      end

      def labels
        metadata[:labels]
      end

      # NOTE: This logic assumes that if there are multiple containers defined
      # in the pod, the container that should run the image from this project
      # is the first container defined.
      def container
        @container ||= Container.new(spec[:containers].first)
      end

      private

      def metadata
        @pod_hash[:metadata]
      end

      def spec
        @pod_hash[:spec]
      end
    end

    class Container

      def initialize(container_hash)
        @container_hash = container_hash
      end

      def cpu
        cpu = limits.try(:[], :cpu) || '200m'
        /(\d+)/.match(cpu).to_s.to_f.try(:/, 1000) #e.g. 0.2 cores
      end

      def ram
        ram = limits.try(:[], :memory) || '512Mi'
        /(\d+)/.match(ram).to_s.to_i
      end

      private

      def resources
        @container_hash[:resources]
      end

      def limits
        resources.try(:[], :limits)
      end

    end

    class Service

      def initialize(service_hash)
        @service_hash = service_hash
      end

      def name
        metadata[:name]
      end

      def labels
        metadata[:labels]
      end

      def selector
        spec[:selector]
      end

      def type
        spec[:type]
      end

      private

      def metadata
        @service_hash[:metadata]
      end

      def spec
        @service_hash[:spec]
      end
    end
  end
end
