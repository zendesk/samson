require 'net/ssh/shell'

class Deploy
  STOP_MESSAGE = "stop"

  def initialize(id)
    @job = JobHistory.find(id)

    perform
    redis.quit
  end

  def perform
    options = { :port => 2222, :forward_agent => true }

    if ENV["DEPLOY_KEY"] && ENV["DEPLOY_PASSPHRASE"]
      options[:key_data] = [ENV["DEPLOY_KEY"]]
      options[:passphrase] = ENV["DEPLOY_PASSPHRASE"]
    end

    success = true

    @ssh = Net::SSH.start("admin01.ord.zdsys.com", "sdavidovitz", options) do |ssh|
      ssh.shell do |sh|
        @job.run!

        [
          "cd #{@job.project.name.parameterize("_")}",
          "git fetch -ap",
          "git reset --hard #{@job.sha}",
          "capsu #{@job.environment} deploy TAG=#{@job.sha}"
        ].each do |command|
          if !exec!(sh, command)
            publish_messages("Failed to execute \"#{command}\"")
            success = false
            break
          end
        end
      end
    end

    if success
      @job.success!
    else
      @job.failed!
    end
  end

  def stop
    return if !@job || @ssh.closed?

    redis = Redis.driver
    redis.set("#{@job.channel}:input", STOP_MESSAGE)
    redis.quit

    @ssh.close
  end

  def exec!(shell, command)
    process = shell.execute(command)

    process.on_output do |ch, data|
      publish_messages(data)
    end

    process.on_error_output do |ch, type, data|
      publish_messages(data, "**ERR")
    end

    process.manager.channel.on_process do
      @job.save if @job.changed?

      if message = redis.get("#{@job.channel}:input")
        redis.del("#{@job.channel}:input")

        if message == STOP_MESSAGE
          return false
        else
          process.send_data("#{message}\n")
        end
      end
    end

    shell.wait!
    process.exit_status == 0
  end

  def publish_messages(data, prefix = "")
    messages = data.split(/\r?\n|\r/).
      map(&:lstrip).reject(&:blank?)

    if prefix.present?
      messages.map! do |msg|
        "#{prefix}#{msg}"
      end
    end

    messages.each do |message|
      @job.log += "#{message}\n"
      redis.publish(@job.channel, message)
      Rails.logger.info(message)
    end
  end

  def redis
    @redis ||= Redis.driver
  end
end
