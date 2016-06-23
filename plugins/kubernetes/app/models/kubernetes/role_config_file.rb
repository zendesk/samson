module Kubernetes
  # Represents a Kubernetes configuration file for a project role.
  # A configuration file can have for example both a Deployment spec and a Service spec
  class RoleConfigFile
    attr_reader :path

    DEPLOY_KINDS = ['Deployment', 'DaemonSet'].freeze
    JOB_KINDS = ['Job'].freeze
    SERVICE_KINDS = ['Service'].freeze

    def initialize(content, path)
      @path = path
      @config = Array.wrap(Kubernetes::Util.parse_file(content, path))
    rescue
      raise Samson::Hooks::UserError, $!.message + " -- #{path}"
    end

    def deploy(**args)
      find_by_kind(DEPLOY_KINDS, **args)
    end

    def service(**args)
      find_by_kind(SERVICE_KINDS, **args)
    end

    def job(**args)
      find_by_kind(JOB_KINDS, **args)
    end

    private

    def find_by_kind(key, required: false)
      matched = @config.select { |doc| key.include?(doc['kind']) }
      if matched.size == 1
        matched.first.with_indifferent_access
      elsif matched.empty? && !required
        nil
      else
        good = (required ? '1 is supported' : '1 or none are supported')
        raise(
          Samson::Hooks::UserError,
          "Config file #{@path} included #{matched.size} objects of kind #{key.join(' or ')}, #{good}"
        )
      end
    end
  end
end
