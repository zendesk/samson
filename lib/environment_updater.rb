require 'lib/ssh_executor'

class EnvironmentUpdater
  attr_reader :projects

  def initialize(projects)
    @projects = projects.to_a.inject({}) do |hash, project|
      hash.merge(project.id => project)
    end
  end

  def run
    return if projects.empty?

    Thread.new do
      commands = projects.values.map do |project|
        [
         "cd #{project.name.parameterize("_")}",
         "git checkout -f master",
         "git pull",
         "bundle check || bundle install --deployment --without test",
         %Q|bundle exec ruby -e "#{script(project)}"|,
         "cd ~"
        ]
      end.flatten

      executor = SshExecutor.new do |command, process|
        process.on_output do |ch, data|
          # zendesk_deployment does upload_log at_exit
          # so we just disregard it
          data = data.split(/\r?\n|\r/).compact.first

          if data && data.start_with?('{')
            json_data = JSON.parse(data)

            project = projects[json_data["id"]]

            environments = json_data["env"].map do |env|
              if env =~ /pod/
                [env, "#{env}:gamma"]
              else
                env
              end
            end

            project.environments = environments.tap(&:flatten!)
            project.save!
          end
        end
      end

      begin
        executor.execute!(*commands)
      rescue Errno::ECONNREFUSED, Net::SSH::ConnectionTimeout, IOError, Timeout::Error => e
        Rails.logger.error("Received #{e.class} when trying EnvironmentUpdater: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
      end
    end
  end

  private

  def script(project)
    script = <<-G
require 'json'

require 'capistrano'
require 'capistrano/cli'

cli = Capistrano::CLI.new([])
cli.instance_variable_set(:@options, { :recipes => ['Capfile'] })

config = cli.instantiate_configuration

cli.load_recipes(config)

puts JSON.dump(:id => #{project.id}, :env => config.fetch(:environments))
    G

    script.gsub!(/(\r?\n|\r)+/, ';')
    script
  end
end
