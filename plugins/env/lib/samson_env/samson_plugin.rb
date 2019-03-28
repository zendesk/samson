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
    def write_env_files(dir, project, deploy_groups)
      return unless groups = env_groups(project, deploy_groups)
      write_dotenv("#{dir}/.env", groups)
    end

    def env_groups(project, deploy_groups, **kwargs)
      groups =
        if deploy_groups.any?
          deploy_groups.map do |deploy_group|
            [
              ".#{deploy_group.name.parameterize}",
              EnvironmentVariable.env(project, deploy_group, **kwargs)
            ]
          end
        else
          [["", EnvironmentVariable.env(project, nil, **kwargs)]]
        end
      return groups if groups.any? { |_, data| data.present? }
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

Samson::Hooks.view :project_form, "samson_env/fields"
Samson::Hooks.view :manage_menu, "samson_env/manage_menu"
Samson::Hooks.view :deploy_confirmation_tab_nav, "samson_env/deploy_tab_nav"
Samson::Hooks.view :deploy_confirmation_tab_body, "samson_env/deploy_tab_body"
Samson::Hooks.view :deploy_tab_nav, "samson_env/deploy_tab_nav"
Samson::Hooks.view :deploy_tab_body, "samson_env/deploy_tab_body"
Samson::Hooks.callback :project_permitted_params do
  [
    AcceptsEnvironmentVariables::ASSIGNABLE_ATTRIBUTES.merge(
      environment_variable_group_ids: []
    ),
    :use_env_repo
  ]
end

Samson::Hooks.callback :after_deploy_setup do |dir, job|
  if stage = job.deploy&.stage
    SamsonEnv.write_env_files(dir, stage.project, stage.deploy_groups.to_a)
  end
end

Samson::Hooks.callback :before_docker_build do |tmp_dir, build, _|
  SamsonEnv.write_env_files(tmp_dir, build.project, [])
end

Samson::Hooks.callback :deploy_group_env do |*args|
  EnvironmentVariable.env(*args)
end

Samson::Hooks.callback(:link_parts_for_resource) do
  [
    "EnvironmentVariable",
    ->(env) do
      scope = " for #{env.scope.name}" if env.scope
      parent = " on #{env.parent.name}" if env.parent
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
Samson::Hooks.view :stage_form, 'samson_env/stage_form'

# Allows environment vars as valid parameters for the stage model
Samson::Hooks.callback :stage_permitted_params do
  AcceptsEnvironmentVariables::ASSIGNABLE_ATTRIBUTES
end

# Injects specific environment variables for the stage when they were set in the form
# NOTE: does not resolve secrets or dollar variables on purpose
Samson::Hooks.callback :deploy_env do |deploy|
  deploy.stage.environment_variables.each_with_object({}) { |var, h| h[var.name] = var.value }
end

if ENV["DEPLOY_ENV_VARS"] != "false" # uncovered
  # Adds the deploy env vars view to the deploy form in order to add
  # specific environment vars per deploy
  Samson::Hooks.view :deploy_form, 'samson_env/deploy_form'

  # Allows environment vars as valid parameters for the deploy model
  Samson::Hooks.callback :deploy_permitted_params do
    AcceptsEnvironmentVariables::ASSIGNABLE_ATTRIBUTES
  end

  # Injects specific environment variables for the deploy when they were set in the form
  # NOTE: does not resolve secrets or dollar variables on purpose
  Samson::Hooks.callback :deploy_env do |deploy|
    deploy.environment_variables.each_with_object({}) { |var, h| h[var.name] = var.value }
  end
end
