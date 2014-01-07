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
      publish_messages("Deploy succeeded.\n")
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
      "cd #{@job.project.repo_name}",
      "git fetch -ap",
      # "mkdir -p /tmp/deploy/#{@job.channel}",
      # "git archive --format tar $(git rev-parse #{@job.sha}) | tar -x -C /tmp/deploy/#{@job.channel}"
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
    @stopped
  end

  def get_message
    @input.pop(true)
  rescue ThreadError
    nil
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
      Rails.logger.info(message)
      @output.push(message)
    end
  end
end
