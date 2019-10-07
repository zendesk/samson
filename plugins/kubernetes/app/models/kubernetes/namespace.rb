# frozen_string_literal: true
require 'kubeclient'

module Kubernetes
  class Namespace < ActiveRecord::Base
    NAME_PATTERN = /\A[a-z]+[a-z\d-]+\z/.freeze

    self.table_name = 'kubernetes_namespaces'
    audited

    default_scope { order(:name) }
    has_many :projects, dependent: nil, foreign_key: :kubernetes_namespace_id, inverse_of: :kubernetes_namespace

    validates :name, presence: true, uniqueness: true, format: NAME_PATTERN
    after_save :remove_configured_resource_names
    before_destroy :ensure_unused

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
        role.update_attributes!(resource_name: nil, service_name: nil, manual_deletion_acknowledged: true)
      end
    end
  end
end
