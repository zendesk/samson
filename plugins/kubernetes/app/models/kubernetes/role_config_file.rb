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
    attr_reader :file_path, :deployment, :service

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
      deployment_hash = as_hash('Deployment')
      raise 'Deployment specification missing in the configuration file.' if deployment_hash.nil?
      @deployment = Deployment.new(deployment_hash, :recurse_over_arrays => true)
    rescue => ex
      Rails.logger.error "Deployment YAML '#{file_path}' invalid: #{ex.message}"
      raise ex
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
    class Deployment < RecursiveOpenStruct
      DEFAULT_RESOURCE_CPU = '99m'
      DEFAULT_RESOURCE_RAM = '512Mi'
      DEFAULT_ROLLOUT_STRATEGY = 'RollingUpdate'

      def cpu_m
        val = first_container.try(:resources).try(:limits).try(:cpu) || DEFAULT_RESOURCE_CPU
        /(\d+(.\d+)?)/.match(val).to_s.to_f.try(:/, 1000)
      end

      def ram_mi
        val = first_container.try(:resources).try(:limits).try(:memory) || DEFAULT_RESOURCE_RAM
        /(\d+)/.match(val).to_s.to_i
      end

      def first_container
        spec.template.spec.containers.first
      end

      def strategy_type
        spec.try(:strategy).try(:type) || DEFAULT_ROLLOUT_STRATEGY
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
