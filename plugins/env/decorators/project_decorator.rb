# frozen_string_literal: true
Project.class_eval do
  include AcceptsEnvironmentVariables

  has_many :external_environment_variable_groups, dependent: :destroy
  has_many :project_environment_variable_groups, dependent: :destroy
  has_many :environment_variable_groups, through: :project_environment_variable_groups, inverse_of: :projects
  accepts_nested_attributes_for :external_environment_variable_groups, allow_destroy: true,
    reject_if: ->(a) { a[:name].blank? || a[:url].blank? }

  def environment_variables_attributes=(*)
    @environment_variables_was ||= serialized_environment_variables
    super
  end

  def environment_variable_group_ids=(*)
    @environment_variables_was ||= serialized_environment_variables
    super
  end

  def audited_changes(...)
    super.merge(environment_variables_changes)
  end

  def serialized_environment_variables
    @env_scopes ||= Environment.env_deploy_group_array # cache since each save needs them twice
    EnvironmentVariable.serialize(nested_environment_variables, @env_scopes)
  end

  def nested_environment_variables(project_specific: nil)
    # Project Specific:
    # nil           => project env + groups env
    # true/"true"   => project env
    # false/"false" => groups env
    case project_specific.to_s
    when "true"
      environment_variables
    when "false"
      environment_variable_groups.flat_map(&:environment_variables)
    else
      [self, *environment_variable_groups].flat_map(&:environment_variables)
    end
  end

  private

  def environment_variables_changes
    return {} unless @environment_variables_was
    environment_variables_is = serialized_environment_variables
    return {} if environment_variables_is == @environment_variables_was
    {"environment_variables" => [@environment_variables_was, environment_variables_is]}
  end
end
