module SamsonEnv
  class Engine < Rails::Engine
  end

  class << self
    def write_env_files(dir, stage)
      return unless groups = env_groups(stage)
      write_manifest_file("#{dir}/ENV.json", groups) ||
        write_dotenv_file("#{dir}/.env", groups)
    end

    def env_groups(stage)
      deploy_groups = stage.deploy_groups.to_a
      groups = if deploy_groups.any?
        deploy_groups.map do |deploy_group|
          [
            ".#{deploy_group.name.parameterize}",
            EnvironmentVariable.env(stage, deploy_group)
          ]
        end
      else
        [["", EnvironmentVariable.env(stage, nil)]]
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
        data = extract_required_keys(generated_file, required_keys, data) if required_keys
        File.write(generated_file, generate_dotenv(data))
      end
    end

    # writes a proprietary .json file with a env hash for each deploy group
    def write_manifest_file(manifest, groups)
      return unless File.exist?(manifest)
      json = JSON.load(File.read(manifest))
      File.unlink(manifest)
      required_keys = json.fetch("env").keys
      groups.each do |suffix, data|
        generated_file = manifest.sub(".json", "#{suffix}.json")
        data = extract_required_keys(generated_file, required_keys, data)
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

    def extract_required_keys(file, required, data)
      file = File.basename(file)
      keys = data.keys
      missing = required - keys
      raise KeyError, "Missing env keys #{missing.join(", ")} for #{file}" if missing.any?
      ignored = keys - required
      Rails.logger.warn("Ignoring env keys #{ignored.join(", ")} for #{file}") if ignored.any?
      data.slice(*required)
    end
  end
end

Samson::Hooks.view :stage_form, "samson_env/fields"
Samson::Hooks.view :admin_menu, "samson_env/admin_menu"

Samson::Hooks.callback :stage_permitted_params do
  AcceptsEnvironmentVariables::ASSIGNABLE_ATTRIBUTES.merge(environment_variable_group_ids: [])
end

Samson::Hooks.callback :after_deploy_setup do |dir, stage|
  SamsonEnv.write_env_files(dir, stage)
end
