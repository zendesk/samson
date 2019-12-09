# frozen_string_literal: true
require 'kubeclient'

module Kubernetes
  class Namespace < ActiveRecord::Base
    NAME_PATTERN = /\A[a-z]+[a-z\d-]+\z/.freeze

    self.table_name = 'kubernetes_namespaces'
    audited

    default_scope { order(:name) }
    has_many :projects, dependent: nil, foreign_key: :kubernetes_namespace_id, inverse_of: :kubernetes_namespace

    validates :name, presence: true, uniqueness: {case_sensitive: false}, format: NAME_PATTERN
    validate :validate_template
    after_save :remove_configured_resource_names
    before_destroy :ensure_unused

    def manifest
      parsed_template.deep_symbolize_keys.deep_merge(
        metadata: {
          name: name,
          annotations: {
            "samson/url": Rails.application.routes.url_helpers.kubernetes_namespace_url(self)
          }
        }
      )
    end

    private

    def ensure_unused
      return if projects.none?
      errors.add :base, 'Can only delete when not used by any project.'
      throw :abort
    end

    # we will no longer use these, so clean the DB up and leave audits behind
    def remove_configured_resource_names
      roles = Kubernetes::Role.
        where(project_id: projects.map(&:id)).
        where("resource_name IS NOT NULL OR service_name IS NOT NULL")
      roles.find_each do |role|
        role.update!(resource_name: nil, service_name: nil, manual_deletion_acknowledged: true)
      end
    end

    # @return [Hash]
    def parsed_template
      YAML.safe_load(template.to_s)
    end

    def validate_template
      unless parsed_template.is_a?(Hash)
        return errors.add :template, "needs to be a Hash"
      end
      errors.add :template, "needs metadata.labels.team" unless parsed_template.dig("metadata", "labels", "team")
    rescue Psych::Exception
      errors.add :template, "needs to be valid yaml"
    end
  end
end
