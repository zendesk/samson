module Kubernetes
  # This file represents a Kubernetes configuration file for a specific project role.
  # A single configuration file can have both a Delpoyment spec and a Service spec, as two separate documents.
  #
  # FIXME: this config reading logic is duplicated in a few places ... unify
  class RoleConfigFile
    attr_reader :file_path

    def initialize(contents, file_path)
      @file_path = file_path
      @config_file = Kubernetes::Util.parse_file(contents, file_path)
    end

    def deployment
      @deployment ||= begin
        deployment_hash = as_hash('Deployment') || as_hash('DaemonSet')
        raise 'Deployment specification missing in the configuration file.' if deployment_hash.nil?
        Deployment.new(deployment_hash)
      end
    rescue => ex
      Rails.logger.error "Config '#{file_path}' invalid: #{ex.message}"
      raise ex
    end

    def service
      return @service if @service
      service_hash = as_hash('Service')
      @service = (Service.new(service_hash) if service_hash)
    rescue => ex
      Rails.logger.error "Config '#{file_path}' invalid: #{ex.message}"
      raise ex
    end

    def job
      @job ||= begin
        job_hash = as_hash('Job')
        raise 'Job specification missing in the configuration file.' if job_hash.nil?
        Job.new(job_hash)
      end
    rescue => ex
      Rails.logger.error "Config '#{file_path}' invalid: #{ex.message}"
      raise ex
    end

    private

    def as_hash(type)
      hash = Array.wrap(@config_file).detect { |doc| doc['kind'] == type }.freeze
      hash.dup.with_indifferent_access unless hash.nil?
    end

    #
    # INNER CLASSES
    #
    class NestedConfig < RecursiveOpenStruct
      def initialize(hash = nil, args = {})
        args[:recurse_over_arrays] = true
        super(hash, args)
      end
    end

    class Deployment < NestedConfig
      DEFAULT_ROLLOUT_STRATEGY = 'RollingUpdate'.freeze

      def strategy_type
        spec.try(:strategy).try(:type) || DEFAULT_ROLLOUT_STRATEGY
      end
    end

    class Service < NestedConfig
    end

    class Job < NestedConfig
    end
  end
end
