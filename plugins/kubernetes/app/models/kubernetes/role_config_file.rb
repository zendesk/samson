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
    attr_reader :replication_controller, :service

    def initialize(contents, filepath)
      @config_file = Kubernetes::Util.parse_file(contents, filepath)
      parse_file
    end

    private

    def parse_file
      parse_replication_controller
      parse_service
    end

    def parse_replication_controller
      @replication_controller = ReplicationController.new(as_hash('ReplicationController'))
    end

    def parse_service
      @service = Service.new(as_hash('Service'))
    end

    def as_hash(type)
      hash = Array.wrap(@config_file).detect { |doc| doc['kind'] == type }.freeze
      hash.dup.with_indifferent_access
    end

    #
    # INNER CLASSES
    #

    class ReplicationController

      def initialize(rc_hash)
        @rc_hash = rc_hash
      end

      def name
        labels[:role]
      end

      def replicas
        spec[:replicas]
      end

      def selector
        spec[:selector]
      end

      def pod_template
        PodTemplate.new(spec[:template])
      end

      def deploy_strategy
        'rolling_update' #TODO: NOT SUPPORTED THROUGH YAML FILE YET ?
      end

      private

      def spec
        @rc_hash[:spec]
      end

      def labels
        @rc_hash[:metadata][:labels]
      end
    end

    class PodTemplate

      def initialize(pod_hash)
        @pod_hash = pod_hash
      end

      # NOTE: This logic assumes that if there are multiple containers defined
      # in the pod, the container that should run the image from this project
      # is the first container defined.
      def container
        Container.new(spec[:containers].first)
      end

      private

      def spec
        @pod_hash[:spec]
      end
    end

    class Container

      def initialize(container_hash)
        @container_hash = container_hash
      end

      def cpu
        cpu = @container_hash.try(:[], :resources).try(:[], :limits).try(:[], :cpu) || '0.2' # TODO: remove defaults
        /(\d+(.\d+)?)/.match(cpu).to_s
      end

      def ram
        ram = @container_hash.try(:[], :resources).try(:[], :limits).try(:[], :memory) || '512' # TODO: remove defaults
        /(\d+)/.match(ram).to_s
      end

    end

    class Service

      def initialize(service_hash)
        @service_hash = service_hash
      end

      def name
        metadata[:name]
      end

      private

      def metadata
        @service_hash[:metadata]
      end
    end
  end
end
