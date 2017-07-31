# frozen_string_literal: true
Project.class_eval do
  include AcceptsEnvironmentVariables

  has_many :project_environment_variable_groups
  has_many :environment_variable_groups, through: :project_environment_variable_groups, dependent: :destroy

  def environment_variables_attributes=(*)
    @environment_variables_was ||= serialized_environment_variables
    super
  end

  def environment_variable_group_ids=(*)
    @environment_variables_was ||= serialized_environment_variables
    super
  end

  def audited_changes
    super.merge(environment_variables_changes)
  end

  def serialized_environment_variables
    @env_scopes ||= Environment.env_deploygroup_array # cache since each save needs them twice
    variables = EnvironmentVariable.nested_variables(self)
    sorted = EnvironmentVariable.sort_by_scopes(variables, @env_scopes)
    sorted.map do |var|
      "#{var.name}=#{var.value.inspect} # #{var.scope&.name || "All"}"
    end.join("\n")
  end

  private

  def environment_variables_changes
    return {} unless @environment_variables_was
    environment_variables_is = serialized_environment_variables
    return {} if environment_variables_is == @environment_variables_was
    {"environment_variables" => [@environment_variables_was, environment_variables_is]}
  end
end
