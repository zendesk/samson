class Deploy
  STOP_MESSAGE = "stop"

  include SuckerPunch::Job
  workers 4

  def perform(id)
    @job = JobHistory.find(id)
    @job.run!

    options = { :port => 2222, :verbose => :debug }

    if ENV["DEPLOY_KEY"]
      options[:key_data] = [ENV["DEPLOY_KEY"]]
    end

    Net::SSH.start("admin01.ord.zdsys.com", "sdavidovitz", options) do |ssh|
      ssh.shell do |sh|
        [
          "cd #{@job.project.name.parameterize("_")}",
          "git fetch -ap",
          "git reset --hard #{@job.sha}",
          "capsu #{@job.environment} deploy TAG=#{@job.sha}"
        ].each do |command|
          if !exec!(sh, command)
            publish_messages("Failed to execute \"#{command}\"")
            @job.failed!

            return
          end
        end
      end
    end

    @job.success!
  end

  def exec!(shell, command)
    retval = true

    Rails.logger.info("Executing \"#{command}\"")
    process = shell.execute(command)

    process.on_output do |ch, data|
      Rails.logger.info("Output: #{data.inspect}")
      publish_messages(data)
    end

    process.on_error_output do |ch, type, data|
      Rails.logger.info("Error output: #{data.inspect}")
      publish_messages(data, "**ERR")
    end

    process.manager.channel.on_process do
      @job.save if @job.changed?

      if message = redis.get("#{@job.channel}:input")
        if message == STOP_MESSAGE
          process.close!
        else
          process.send_data("#{message}\n")
        end

        redis.del("#{@job.channel}:input")
      end
    end

    Rails.logger.info("Waiting")
    shell.wait!
    Rails.logger.info("Exit status: #{process.exit_status}")
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
    @redis ||= REDIS
  end
end
