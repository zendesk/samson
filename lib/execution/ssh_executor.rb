require 'net/ssh/shell'

module Execution
  class Ssh < Base
    def initialize(options = {})
      super()

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
    end

    def execute!(*commands)
      Net::SSH.start(@host, @user, @options) do |ssh|
        ssh.shell do |shell|
          commands.each do |command|
            if !execute_command(shell, command)
              publish_message("Failed to execute \"#{command}\"")
              return false
            end
          end
        end
      end

      true
    end

    private

    def execute_command(shell, command)
      process = shell.execute(command)

      process.on_output do |ch, data|
        lines(data).each do |line|
          @callbacks[:stdout].each {|callback| callback.call(line)}
        end
      end

      process.on_error_output do |ch, type, data|
        lines(data).each do |line|
          @callbacks[:stderr].each {|callback| callback.call(line)}
        end
      end

      process.manager.channel.on_process do
        @callbacks[:process].each do |callback|
          callback.call(command, process)
        end
      end

      shell.wait!
      process.exit_status == 0
    end

    def lines(data)
      data.split(/\r?\n|\r/).
        map(&:lstrip).reject(&:blank?)
    end
  end
end
