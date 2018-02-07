# frozen_string_literal: true
module Kubernetes
  # Represents a Kubernetes configuration file for a project role.
  # A configuration file can have for example both a Deployment spec and a Service spec
  # ... this is no longer needed ... merge into release_doc
  class RoleConfigFile
    attr_reader :path, :elements

    DEPLOY_KINDS = ['Deployment', 'DaemonSet', 'StatefulSet'].freeze
    JOB_KINDS = ['Job'].freeze
    PRIMARY_KINDS = (DEPLOY_KINDS + JOB_KINDS + ['Pod']).freeze
    SERVICE_KINDS = ['Service'].freeze
    PREREQUISITE = [:metadata, :annotations, :'samson/prerequisite'].freeze

    def initialize(content, path)
      @path = path

      if content.blank?
        raise Samson::Hooks::UserError, "does not contain config file '#{path}'"
      end

      begin
        @elements = Array.wrap(Kubernetes::Util.parse_file(content, path)).compact.map(&:deep_symbolize_keys)
      rescue
        raise Samson::Hooks::UserError, "Error found when parsing #{path}\n#{$!.message}"
      end
    end

    def primary
      find_by_kind(PRIMARY_KINDS).first
    end

    def services
      find_by_kind(SERVICE_KINDS)
    end

    private

    def find_by_kind(kinds)
      @elements.select { |doc| kinds.include?(doc[:kind]) }
    end
  end
end
