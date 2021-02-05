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

  validates :name, presence: true
  validate :validate_external_url_valid, if: :external_url?

  def variable_names
    environment_variables.sort_by(&:id).map(&:name).uniq
  end

  def as_json(methods: [], **options)
    super({methods: [:variable_names] + methods}.merge(options))
  end

  private

  def validate_external_url_valid
    e = ExternalEnvironmentVariableGroup.new(url: external_url, name: "Foo", project: Project.new)
    return if e.valid?
    errors.add :external_url, e.errors.full_messages.to_sentence
  end
end
