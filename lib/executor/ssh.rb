require_relative 'base'
require 'extensions/net/ssh'
require 'net/ssh/shell'

module Executor
  class Ssh < Base
    def initialize(options = {})
      self.class.create_auth_sock

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

      @callbacks[:process] = []
      @stopped = false
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

    def stop!
      @stopped = true
    end

    def stopped?
      @stopped
    end

    def process(&block)
      @callbacks[:process] << block
    end

    def self.create_auth_sock
      return if ENV["SSH_AUTH_SOCK"].present?

      socket = Rails.root.join("tmp/auth_sock")

      unless File.exist?(socket)
        Process.spawn({ "DEPLOY_KEY" => ENV['DEPLOY_KEY'].gsub(/\\n/, "\n") }, Rails.root.join("lib/ssh-agent.sh").to_s)

        time = Time.now

        until File.exist?(socket)
          if (Time.now - time) >= 5
            Rails.logger.error("Could not start SSH Agent!")
            return
          end
        end
      end

      ENV["SSH_AUTH_SOCK"] = File.readlink(socket)
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
        if stopped?
          return false
        end

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
