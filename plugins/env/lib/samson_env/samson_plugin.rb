module SamsonEnv
  class Engine < Rails::Engine
  end

  class << self
    def write_env_files(dir, job)
      return unless (stage = job.deploy.try(:stage))
      return unless groups = env_groups(stage.project, stage.deploy_groups.to_a)
      write_env_json_file("#{dir}/ENV.json", "#{dir}/manifest.json", groups) ||
        write_dotenv_file("#{dir}/.env", groups)
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
    def write_dotenv_file(base_file, groups)
      required_keys = parse_dotenv(base_file).keys if File.exist?(base_file)
      File.unlink(base_file) if File.exist?(base_file)
      groups.each do |suffix, data|
        generated_file = "#{base_file}#{suffix}"
        data = extract_keys(generated_file, required_keys, [], data) if required_keys
        File.write(generated_file, generate_dotenv(data))
      end
    end

    # writes a proprietary .json file with a env hash for each deploy group
    def write_env_json_file(env_json, manifest_json, groups)
      return unless File.exist?(manifest_json)
      json =
        if File.exist?(env_json)
          JSON.load(File.read(env_json)).tap { File.unlink(env_json) }
        else
          {}
        end

      # manifest.json includes required keys and other things we copy
      manifest = JSON.load(File.read(manifest_json))
      settings = manifest.delete("settings")

      # hackaround to support projects that have a manifest.json for
      # a completely different purpose such as github.com/zendesk/timetracking_app
      return false if settings.nil?
      json.reverse_merge!(manifest)
      required_keys, optional_keys = settings.keys.partition do |key|
        settings[key].fetch("required", true)
      end

      groups.each do |suffix, data|
        generated_file = env_json.sub(".json", "#{suffix}.json")
        data = extract_keys(generated_file, required_keys, optional_keys, data)
        File.write(generated_file, JSON.pretty_generate(json.merge("env" => data)))
      end
    end

    def parse_dotenv(file)
      Dotenv::Parser.call(File.read(file))
    end

    # https://github.com/bkeepers/dotenv/pull/188
    def generate_dotenv(data)
      data.map { |k, v| "#{k}=#{v.inspect.gsub("$", "\\$")}" }.join("\n") << "\n"
    end

    def extract_keys(file, required, optional, data)
      all = required + optional
      file = File.basename(file)
      keys = data.keys
      missing = required - keys
      raise Samson::Hooks::UserError, "Missing env keys #{missing.join(", ")} for #{file}" if missing.any?
      ignored = keys - all
      Rails.logger.warn("Ignoring env keys #{ignored.join(", ")} for #{file}") if ignored.any?
      data.slice(*all)
    end
  end
end

Samson::Hooks.view :project_form, "samson_env/fields"
Samson::Hooks.view :admin_menu, "samson_env/admin_menu"

Samson::Hooks.callback :project_permitted_params do
  AcceptsEnvironmentVariables::ASSIGNABLE_ATTRIBUTES.merge(environment_variable_group_ids: [])
end

Samson::Hooks.callback :after_deploy_setup do |dir, stage|
  SamsonEnv.write_env_files(dir, stage)
end
