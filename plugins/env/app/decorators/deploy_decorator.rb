# frozen_string_literal: true

Deploy.class_eval do
  include AcceptsEnvironmentVariables

  before_create :store_env_state

  def retrieve_env_state
    persisted? ? env_state : serialized_environment_variables
  end

  private

  def serialized_environment_variables
    if groups = SamsonEnv.env_groups(self, stage.deploy_groups, preview: true, resolve_secrets: false)
      groups.map do |name, data|
        name = name.empty? ? '' : "# #{name.delete('.').titleize}\n"
        "#{name}#{SamsonEnv.generate_dotenv(data)}"
      end.join("\n")
    else
      ''
    end
  end

  def store_env_state
    self.env_state = serialized_environment_variables
  end
end
