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
    before_destroy :ensure_unused

    private

    def ensure_unused
      return if projects.none?
      errors.add :base, 'Can only delete when not used by any project.'
      throw :abort
    end
  end
end
