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

  # Sorted as the UI displays them in _environment_variables.html.erb
  # Combined variables as .env does it in environment_variable.rb
  # TODO: diffing in versions UI
  def serialized_environment_variables
    @env_scopes ||= Environment.env_deploygroup_array # cache since each save needs them twice
    variables = environment_variables + environment_variable_groups.flat_map(&:environment_variables)
    sorted = variables.sort_by { |x| [x.name, @env_scopes.index { |_, s| s == x.scope_type_and_id } || 999] }
    sorted.map do |var|
      "#{var.name}=#{var.value.inspect} # #{var.scope&.name || "All"}"
    end.join("\n")
  end

  def record_environment_variable_change(env_was)
    @environment_variables_was = env_was
    return unless changes = environment_variables_changes.presence
    write_audit(action: 'update', audited_changes: changes)
  end

  private

  def environment_variables_changes
    return {} unless @environment_variables_was
    environment_variables_is = serialized_environment_variables
    return {} if environment_variables_is == @environment_variables_was
    {"environment_variables" => [@environment_variables_was, environment_variables_is]}
  end
end
