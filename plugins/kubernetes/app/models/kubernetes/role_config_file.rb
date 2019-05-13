# frozen_string_literal: true
module Kubernetes
  # Represents a Kubernetes configuration file for a project role.
  # A configuration file can have for example both a Deployment spec and a Service spec
  # ... this is no longer needed ... merge into release_doc
  class RoleConfigFile
    attr_reader :path, :elements

    DEPLOY_KINDS = ['Deployment', 'DaemonSet', 'StatefulSet'].freeze
    SERVICE_KINDS = ['Service'].freeze
    PREREQUISITE = [:metadata, :annotations, :'samson/prerequisite'].freeze

    # TODO: rename to has_pods? or so
    def self.primary?(resource)
      templates(resource).any?
    end

    def self.templates(resource)
      spec = resource[:spec]
      if !spec
        []
      elsif spec[:containers]
        [resource]
      else
        spec.values_at(*template_keys(resource)).flat_map { |r| templates(r) }
      end
    end

    def self.template_keys(resource)
      (resource[:spec] || {}).keys.grep(/template$/i)
    end

    def initialize(content, path, **args)
      @path = path

      if content.blank?
        raise Samson::Hooks::UserError, "does not contain config file '#{path}'"
      end

      begin
        @elements = Array.wrap(Kubernetes::Util.parse_file(content, path)).compact.map(&:deep_symbolize_keys)
      rescue
        raise Samson::Hooks::UserError, "Error found when parsing #{path}\n#{$!.message}"
      end

      if errors = Kubernetes::RoleValidator.new(@elements, **args).validate
        raise Samson::Hooks::UserError, "Error found when validating #{path}\n#{errors.join("\n")}"
      end
    end

    def primary
      @elements.detect { |e| self.class.primary?(e) }
    end

    def services
      @elements.select { |doc| SERVICE_KINDS.include?(doc[:kind]) }
    end
  end
end
