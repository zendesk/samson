# frozen_string_literal: true
class EnvironmentVariableGroup < ActiveRecord::Base
  include AcceptsEnvironmentVariables
  extend AuditOnAssociation

  audits_on_association(
    :projects,
    :environment_variable_groups,
    audit_name: :environment_variables,
    &:serialized_environment_variables
  )

  default_scope -> { order(:name) }

  has_many :project_environment_variable_groups, dependent: :destroy
  has_many :projects, through: :project_environment_variable_groups

  validates :name, presence: true
end
