# frozen_string_literal: true
module SamsonEnv
  HELP_TEXT = "$VAR / ${VAR} replacements supported. Priority is DeployGroup, Environment, All. " \
    "Secrets can be used with secret://key_of_secrect."

  class Engine < Rails::Engine
  end

  class << self
    def write_env_files(dir, job)
      return unless (stage = job.deploy.try(:stage))
      return unless groups = env_groups(stage.project, stage.deploy_groups.to_a)
      write_dotenv("#{dir}/.env", groups)
    end

    def env_groups(project, deploy_groups, preview: false)
      groups =
        if deploy_groups.any?
          deploy_groups.map do |deploy_group|
            [
              ".#{deploy_group.name.parameterize}",
              EnvironmentVariable.env(project, deploy_group, preview: preview)
            ]
          end
        else
          [["", EnvironmentVariable.env(project, nil, preview: preview)]]
        end
      return groups if groups.any? { |_, data| data.present? }
    end

    private

    # writes .env file for each deploy group
    def write_dotenv(base_file, groups)
      File.unlink(base_file) if File.exist?(base_file)

      groups.each do |suffix, data|
        generated_file = "#{base_file}#{suffix}"
        File.write(generated_file, generate_dotenv(data))
      end
    end

    # https://github.com/bkeepers/dotenv/pull/188
    # shellescape does not work ... we only get strings, so inspect works pretty well
    def generate_dotenv(data)
      data.map { |k, v| "#{k}=#{v.inspect.gsub("$", "\\$")}" }.join("\n") << "\n"
    end
  end
end

Samson::Hooks.view :project_form, "samson_env/fields"
Samson::Hooks.view :admin_menu, "samson_env/admin_menu"

Samson::Hooks.callback :project_permitted_params do
  AcceptsEnvironmentVariables::ASSIGNABLE_ATTRIBUTES.merge(environment_variable_group_ids: [])
end

Samson::Hooks.callback :after_deploy_setup do |dir, job|
  SamsonEnv.write_env_files(dir, job)
end

Samson::Hooks.callback :deploy_group_env do |project, deploy_group|
  EnvironmentVariable.env(project, deploy_group)
end
