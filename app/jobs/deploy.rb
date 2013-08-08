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
      [
        "cd #{@job.project.name}",
        "git fetch -ap",
        "git reset --hard #{@job.sha}",
        "bundle --deployment",
        "capsu #{@job.environment} deploy TAG=#{@job.sha}"
      ].each do |command|
        if !ssh_exec!(ssh, command)
          return false
          break
        end
      end
    end
  end

  def ssh_exec!(ssh, command)
    retval = true

    channel = ssh.open_channel do |ch|
      channel.exec(command) do |ch, success|
        if !success
          abort "FAILED: couldn't execute command (ssh.channel.exec)"
          @job.log += "Could not execute command \"#{command}\""
        end

        channel.on_data do |ch, data|
          @job.log += data
        end

        channel.on_extended_data do |ch, type, data|
          @job.log += "**err: #{data}"
        end

        channel.on_request("exit-status") do |ch,data|
          retval = data.read_long == 0
        end
      end
    end

    channel.wait
    retval
  end
end
