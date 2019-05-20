# frozen_string_literal: true
module SamsonEnv
  HELP_TEXT = <<~TEXT.html_safe
    <ul>
      <li>$VAR / ${VAR} replacements supported</li>
      <li>Priority is Deploy, Stage, Project, DeployGroup, Environment, All</li>
      <li>Secrets can be used with secret://key_of_secret</li>
      <li>env vars are written to .env{.deploy-group} files and need to be loaded by the app via Dotenv library or <code>set -a;source .env;set +a</code></li>
    </ul>
  TEXT

  class Engine < Rails::Engine
  end

  class << self
    def write_env_files(dir, deploy, deploy_groups)
      return unless groups = env_groups(deploy, deploy_groups)
      write_dotenv("#{dir}/.env", groups)
    end

    def env_groups(deploy, deploy_groups, **kwargs)
      groups =
        if deploy_groups.any?
          deploy_groups.map do |deploy_group|
            [
              ".#{deploy_group.name.parameterize}",
              EnvironmentVariable.env(deploy, deploy_group, **kwargs)
            ]
          end
        else
          [["", EnvironmentVariable.env(deploy, nil, **kwargs)]]
        end
      groups if groups.any? { |_, data| data.present? }
    end

    # https://github.com/bkeepers/dotenv/pull/188
    # shellescape does not work ... we only get strings, so inspect works pretty well
    def generate_dotenv(data)
      data.map { |k, v| "#{k}=#{v.inspect.gsub("$", "\\$")}" }.join("\n") << "\n"
    end

    private

    # writes .env file for each deploy group
    def write_dotenv(base_file, groups)
      File.unlink(base_file) if File.exist?(base_file)

      groups.each do |suffix, data|
        generated_file = "#{base_file}#{suffix}"
        File.write(generated_file, generate_dotenv(data), 0, perm: 0o640)
      end
    end
  end
end

# TODO: lazy load environment variables via changeset to make preview for new deploy show entered deploy env vars
Samson::Hooks.view :project_form, "samson_env"
Samson::Hooks.view :manage_menu, "samson_env"
Samson::Hooks.view :deploy_confirmation_tab_nav, "samson_env/deploy_tab_nav"
Samson::Hooks.view :deploy_confirmation_tab_body, "samson_env/deploy_tab_body"
Samson::Hooks.view :deploy_tab_nav, "samson_env"
Samson::Hooks.view :deploy_tab_body, "samson_env"
Samson::Hooks.callback :project_permitted_params do
  [
    AcceptsEnvironmentVariables::ASSIGNABLE_ATTRIBUTES.merge(
      environment_variable_group_ids: []
    ),
    :use_env_repo,
    :config_service
  ]
end

Samson::Hooks.callback :after_deploy_setup do |dir, job|
  next unless deploy = job.deploy
  SamsonEnv.write_env_files(dir, deploy, deploy.stage.deploy_groups.to_a)
end

Samson::Hooks.callback :before_docker_build do |tmp_dir, build, _|
  SamsonEnv.write_env_files(tmp_dir, Deploy.new(project: build.project), [])
end

# TODO: not used for write_env_files
Samson::Hooks.callback :deploy_env do |*args|
  EnvironmentVariable.env(*args)
end

Samson::Hooks.callback(:link_parts_for_resource) do
  [
    "EnvironmentVariable",
    ->(env) do
      scope = " for #{env.scope.name}" if env.scope
      parent = " on #{env.parent&.name || "Deleted"}"
      ["#{env.name}#{scope}#{parent}", EnvironmentVariable]
    end
  ]
end
Samson::Hooks.callback(:link_parts_for_resource) do
  [
    "EnvironmentVariableGroup",
    ->(env_group) { [env_group.name, env_group] }
  ]
end

Samson::Hooks.callback(:can) do
  [
    :environment_variable_groups,
    ->(user, action, group) do
      case action
      when :write
        return true if user.admin?

        administrated = user.administrated_projects.pluck(:id)
        return true if administrated.any? && group.projects.pluck(:id).all? { |id| administrated.include?(id) }

        false
      else
        raise ArgumentError, "Unsupported action #{action}"
      end
    end
  ]
end

# Adds the stage env vars view to the stage form in order to add
# specific environment vars per stage
Samson::Hooks.view :stage_form, 'samson_env'

# Allows environment vars as valid parameters for the stage model
Samson::Hooks.callback :stage_permitted_params do
  AcceptsEnvironmentVariables::ASSIGNABLE_ATTRIBUTES
end

# TODO: remove this, just for backwards compatibility and broken since it does not check scope
Samson::Hooks.callback :deploy_execution_env do |deploy|
  deploy.stage.environment_variables.each_with_object({}) { |var, h| h[var.name] = var.value }
end

env_vars_flag = ENV["DEPLOY_ENV_VARS"]
if env_vars_flag != "false" # uncovered
  if env_vars_flag != 'api_only' # uncovered
    # Adds the deploy env vars view to the deploy form in order to add
    # specific environment vars per deploy
    Samson::Hooks.view :deploy_form, 'samson_env'
  end

  # Allows environment vars as valid parameters for the deploy model
  Samson::Hooks.callback :deploy_permitted_params do
    AcceptsEnvironmentVariables::ASSIGNABLE_ATTRIBUTES
  end
end
