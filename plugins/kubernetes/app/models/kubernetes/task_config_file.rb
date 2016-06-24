module Kubernetes
  # This file represents a Kubernetes configuration file for a specific project macro task.
  class TaskConfigFile
    attr_reader :file_path, :job

    def initialize(contents, file_path)
      @file_path = file_path
      @config_file = Kubernetes::Util.parse_file(contents, file_path)
      parse_file
    end

    private

    def parse_file
      job_hash = as_hash('Job')
      raise 'Job specification missing in the configuration file.' if job_hash.nil?
      @job = Job.new(job_hash)
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
    class Job < RecursiveOpenStruct
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
    end
  end
end
