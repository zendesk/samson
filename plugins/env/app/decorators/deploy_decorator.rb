# frozen_string_literal: true

Deploy.class_eval do
  before_create :store_env_state

  def retrieve_env_state
    persisted? ? env_state : serialized_environment_variables
  end

  private

  def serialized_environment_variables
    variables = EnvironmentVariable.nested_variables(project)

    if deploy_groups = stage.deploy_groups.presence
      variables = variables.select { |ev| deploy_groups.any? { |dg| ev.matches_scope?(dg) } }
    end

    EnvironmentVariable.serialize(variables, Environment.env_deploy_group_array)
  end

  def store_env_state
    self.env_state = serialized_environment_variables
  end
end
