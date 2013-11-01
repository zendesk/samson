require 'soft_deletion'

class Project < ActiveRecord::Base
  # Heroku passes a fake DB to precompilation, fail
  begin
    has_soft_deletion
  rescue
  end

  validates_presence_of :name

  has_many :job_histories, -> { order("created_at DESC") }
  has_many :job_locks, -> { order("created_at DESC") }

  after_create :update_project_environments

  serialize :environments

  def to_param
    "#{id}-#{name.parameterize}"
  end

  def environments
    read_attribute(:environments) || []
  end

  def self.update_project_environments
    Thread.new do
      require 'lib/ssh_executor'

      projects = Project.where(deleted_at: nil).to_a.inject({}) {|h,p| h.merge(p.id => p)}
      commands = projects.values.map do |project|
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

        ["cd #{project.name.parameterize("_")}", "bundle check || bundle install --deployment --without test", %Q|bundle exec ruby -e "#{script}"|, "cd ~"]
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

      executor.execute!(*commands)
    end
  end

  def update_project_environments
    self.class.update_project_environments
  end
end
