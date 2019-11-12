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
  has_many :projects, through: :project_environment_variable_groups, inverse_of: :environment_variable_groups
  has_many :environment_variable_group_owners, dependent: :destroy
  accepts_nested_attributes_for :environment_variable_group_owners,
    allow_destroy: true, reject_if: ->(a) { a[:name].blank? }

  validates :name, presence: true

  def variable_names
    environment_variables.sort_by(&:id).map(&:name).uniq
  end

  def owners
    environment_variable_group_owners.sort_by(&:id).map(&:name)
  end

  def as_json(methods: [], **options)
    super({methods: [:variable_names, :owners] + methods}.merge(options))
  end
end
