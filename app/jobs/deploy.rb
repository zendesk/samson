class Deploy < Resque::Job
  def self.queue
    :deployment
  end

  def self.perform(job_history)
    job = new(job_history)

    if job.work
      job_history.success!
    else
      job_history.failure!
    end
  end

  def initialize(job)
    @job = job
  end

  def work
    Net::SSH.start("admin04.pod1", "sdavidovitz") do |ssh|
      ssh.shell do |sh|
        [
          "cd #{@job.project.name.downcase}",
          "git fetch -ap",
          "git reset --hard #{@job.sha}",
          "bundle --deployment",
          "capsu #{@job.environment} deploy TAG=#{@job.sha}"
        ].each do |command|
          if !exec!(sh, command)
            return false
            break
          end
        end
      end
    end
  end

  def exec!(shell, command)
    retval = true

    process = shell.execute(command)
    process.on_output do |ch, data|
      @job.log += data
      redis.publish(@job.channel, data)
      Rails.logger.info(data)
    end

    process.on_error_output do |ch, type, data|
      msg = "**err: #{data}"

      @job.log += msg
      redis.publish(@job.channel, msg)
      Rails.logger.error(data)
    end

    process.manager.channel.on_request("exit-status") do |ch,data|
      retval = data.read_long == 0
    end

    process.wait!
    retval
  end

  def redis
    @redis ||= Resque.redis.redis
  end
end
