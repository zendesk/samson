module Kubernetes
  # This file represents a Kubernetes configuration file for a specific project role.
  # A single configuration file can have both a Delpoyment spec and a Service spec, as two separate documents.
  class RoleConfigFile
    attr_reader :file_path, :deployment, :service

    def initialize(contents, file_path)
      @file_path = file_path
      @config_file = Kubernetes::Util.parse_file(contents, file_path)
      parse_file
    end

    private

    def parse_file
      parse_deployment
      parse_service
    end

    def parse_deployment
      deployment_hash = as_hash('Deployment') || as_hash('DaemonSet')
      raise 'Deployment specification missing in the configuration file.' if deployment_hash.nil?
      @deployment = Deployment.new(deployment_hash)
    rescue => ex
      Rails.logger.error "Deployment YAML '#{file_path}' invalid: #{ex.message}"
      raise ex
    end

    def parse_service
      service_hash = as_hash('Service')
      @service = Service.new(service_hash) unless service_hash.nil?
    rescue => ex
      Rails.logger.error "Deployment YAML '#{file_path}' invalid: #{ex.message}"
      raise ex
    end

    def as_hash(type)
      hash = Array.wrap(@config_file).detect { |doc| doc['kind'] == type }.freeze
      hash.dup.with_indifferent_access unless hash.nil?
    end

    #
    # INNER CLASSES
    #
    class Deployment < RecursiveOpenStruct
      DEFAULT_RESOURCE_CPU = '99m'.freeze
      DEFAULT_RESOURCE_RAM = '512Mi'.freeze
      DEFAULT_ROLLOUT_STRATEGY = 'RollingUpdate'.freeze

      def initialize(hash = nil, args = {})
        args[:recurse_over_arrays] = true
        super(hash, args)
      end

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

    class Service < RecursiveOpenStruct
      def initialize(hash = nil, args = {})
        args[:recurse_over_arrays] = true
        super(hash, args)
      end
    end
  end
end
