require 'net/ssh/shell'

class SshExecutor
  def initialize(options = {}, &block)
    default_options = {
      :port => 2222, :forward_agent => true, :timeout => 20
    }

    if ENV["DEPLOY_KEY"]
      default_options[:key_data] = [ENV["DEPLOY_KEY"]]
    end

    @options = default_options.merge(options)
    @host = if Rails.env.staging?
      "deploy1.rsc.zdsys.com"
    else
      "admin01.ord.zdsys.com"
    end

    @user = if Rails.env.development?
      config = Net::SSH.configuration_for("pod1")
      config && config[:user] ? config[:user] : ENV["USER"]
    else
      "deploy"
    end

    @callbacks = block
  end

  def execute!(*commands)
    Net::SSH.start(@host, @user, @options) do |ssh|
      ssh.shell do |shell|
        commands.each do |command|
          if !execute_command(shell, command)
            return [false, command]
          end
        end
      end
    end

    [true, nil]
  end

  def execute_command(shell, command)
    process = shell.execute(command)

    @callbacks.call(command, process)

    shell.wait!
    process.exit_status == 0
  end
end
