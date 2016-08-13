# frozen_string_literal: true
module Kubernetes
  # Represents a Kubernetes configuration file for a project role.
  # A configuration file can have for example both a Deployment spec and a Service spec
  class RoleConfigFile
    attr_reader :path, :elements

    DEPLOY_KINDS = ['Deployment', 'DaemonSet'].freeze
    JOB_KINDS = ['Job'].freeze
    SERVICE_KINDS = ['Service'].freeze

    def initialize(content, path)
      @path = path

      if content.blank?
        raise Samson::Hooks::UserError, "does not contain config file '#{path}'"
      end

      begin
        @elements = Array.wrap(Kubernetes::Util.parse_file(content, path)).compact
      rescue
        raise Samson::Hooks::UserError, "Error found when parsing #{path}\n#{$!.message}"
      end

      if errors = Kubernetes::RoleVerifier.new(@elements).verify
        raise Samson::Hooks::UserError, "Error found when parsing #{path}\n#{errors.join("\n")}"
      end
    end

    def deploy
      find_by_kind(DEPLOY_KINDS)
    end

    def service
      find_by_kind(SERVICE_KINDS)
    end

    def job
      find_by_kind(JOB_KINDS)
    end

    private

    def find_by_kind(kinds)
      @elements.detect do |doc|
        return doc.with_indifferent_access if kinds.include?(doc['kind'])
      end
    end
  end
end
