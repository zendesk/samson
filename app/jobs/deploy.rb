require 'net/ssh/shell'

class Deploy
  attr_reader :job_id

  def initialize(id)
    @job_id, @job = id, JobHistory.find(id)
    @stopped = false
  end

  def perform
    @job.run!

    # Give the stream a little time to start
    sleep(1.5)

    success = true

    publish_messages("Please enter your passphrase:\n")
    @job.save

    options = { :port => 2222, :forward_agent => true, :timeout => 20 }

    if ENV["DEPLOY_KEY"]
      options[:key_data] = [ENV["DEPLOY_KEY"]]
    end

    until options[:passphrase] = get_message
      if stopped?
        publish_messages("Deploy stopped.\n")
        success = false
        break
      end
    end

    Rails.logger.info("Found passphrase, continuing with deploy? #{success.inspect}")

    if success && ssh_deploy(options)
      @job.success!
    else
      @job.failed!
    end

    redis.quit
  end

  def ssh_deploy(options)
    if Rails.env.production?
      Process.wait(Process.spawn("#{Rails.root.join("lib/ssh-agent.sh")} #{options[:passphrase]}")
      ENV["SSH_AUTH_SOCK"] = File.readlink(Rails.root.join("tmp/auth_sock"))
    end

    @ssh = Net::SSH.start("admin01.ord.zdsys.com", "sdavidovitz", options) do |ssh|
      ssh.shell do |sh|
        [
          "cd #{@job.project.name.parameterize("_")}",
          "git fetch -ap",
          "git reset --hard #{@job.sha}",
          "capsu #{@job.environment} deploy TAG=#{@job.sha}"
        ].each do |command|
          if !exec!(sh, command)
            publish_messages("Failed to execute \"#{command}\"")
            return false
          end
        end
      end
    end

    true
  rescue Net::SSH::ConnectionTimeout
    publish_messages("SSH connection timeout.")
    false
  end

  def stop
    return if !@job || @ssh.try(:closed?)

    @stopped = true
    Rails.logger.info("Deploy #{@job_id} stopped")
  end

  # When not on Heroku, should be changed
  # to read from a :stopped redis key
  def stopped?
    @stopped
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
      return false if stopped?
      @job.save if @job.changed?

      if message = get_message
        process.send_data("#{message}\n")
      end
    end

    shell.wait!
    process.exit_status == 0
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
