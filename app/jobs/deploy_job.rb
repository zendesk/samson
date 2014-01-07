require Rails.root.join('lib', 'ssh_executor')
require 'net/ssh'

class DeployJob
  attr_reader :job_id, :job, :output, :publisher

  def initialize(id)
    @job_id, @job = id, JobHistory.find(id)

    @input, @output = Queue.new, DeployOutput.new
    @stopped = false
  end

  def perform
    @job.run!

    if ssh_deploy
      publish_message("Deploy succeeded.")
      @job.success!
    else
      @job.failed!
    end
  end

  def stop
    @stopped = true
  end

  def input(message)
    @input.push(message)
  end

  private

  def ssh_deploy
    @ssh = SshExecutor.new
    @ssh.output do |message|
      publish_message(message)
    end

    @ssh.error_output do |message|
      publish_message("**ERR #{data}")
    end

    @ssh.process do |command, process|
      if stopped?
        publish_message("Stopped command \"#{command}\"")
        return false
      end

      @job.save if @job.changed?

      if message = get_message
        process.send_data("#{message}\n")
      end
    end

    @ssh.execute!(
      "export SUDO_USER=#{@job.user.email}",
      "cd #{@job.project.repo_name}",
      "git fetch -ap",
      # "mkdir -p /tmp/deploy/#{@job.channel}",
      # "git archive --format tar $(git rev-parse #{@job.sha}) | tar -x -C /tmp/deploy/#{@job.channel}"
      "git checkout -f #{@job.sha}",
      "! (git status | grep 'On branch') || git pull",
      "capsu $(pwd) $(rvm current | tail -1) #{@job.environment} deploy TAG=#{@job.sha}"
    )
  rescue Errno::ECONNREFUSED, Net::SSH::ConnectionTimeout
    publish_message("SSH connection timeout.")
    false
  rescue IOError => e
    Rails.logger.info("Deploy failed: #{e.message}")
    Rails.logger.info(e.backtrace)

    publish_message("Deploy failed.")
    false
  end

  def stopped?
    @stopped
  end

  def get_message
    @input.pop(true)
  rescue ThreadError
    nil
  end

  def publish_message(message)
    @job.log += "#{message}\n"
    Rails.logger.info(message)
    @output.push(message)
  end
end
