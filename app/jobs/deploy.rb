require 'lib/ssh_executor'

class Deploy
  attr_reader :job_id

  def initialize(id)
    @job_id, @job = id, JobHistory.find(id)
  end

  def perform
    @job.run!

    if ssh_deploy
      publish_messages("Deploy succeeded.\n")
      @job.success!
    else
      @job.failed!
    end

    redis.quit
  end

  def ssh_deploy
    socket = Rails.root.join("tmp/auth_sock")

    @ssh = SshExecutor.new do |command, process|
      process.on_output do |ch, data|
        publish_messages(data)
      end

      process.on_error_output do |ch, type, data|
        publish_messages(data, "**ERR")
      end

      process.manager.channel.on_process do
        if stopped?
          publish_messages("Stopped command \"#{command}\"")
          return false
        end

        @job.save if @job.changed?

        if message = get_message
          process.send_data("#{message}\n")
        end
      end
    end

    retval, command = @ssh.execute!(
      "export SUDO_USER=#{@job.user.email}",
      "cd #{@job.project.name.parameterize("_")}",
      "git fetch -ap",
      "git checkout -f #{@job.sha}",
      "! (git status | grep 'On branch') || git pull",
      "capsu $(pwd) $(rvm current | tail -1) #{@job.environment} deploy TAG=#{@job.sha}"
    )

    unless retval
      publish_messages("Failed to execute \"#{command}\"")
    end

    retval
  rescue Errno::ECONNREFUSED, Net::SSH::ConnectionTimeout
    publish_messages("SSH connection timeout.")
    false
  rescue IOError => e
    Rails.logger.info("Deploy failed: #{e.message}")
    Rails.logger.info(e.backtrace)

    publish_messages("Deploy failed.")
    false
  end

  def stopped?
    @stopped ||= redis.get("#{@job.channel}:stop").present?.tap do |present|
      redis.del("#{@job.channel}:stop") if present
    end
  end

  def get_message
    redis.get("#{@job.channel}:input").tap do |message|
      redis.del("#{@job.channel}:input") if message
    end
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
