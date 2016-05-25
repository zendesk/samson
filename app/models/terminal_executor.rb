require 'open3'

# Executes commands in a fake terminal. The output will be streamed to a
# specified IO-like object.
#
# Example:
#
#   output = StringIO.new
#   terminal = TerminalExecutor.new(output)
#   terminal.execute!("echo hello", "echo world")
#
#   output.string #=> "hello\r\nworld\r\n"
#
class TerminalExecutor
  SECRET_PREFIX = "secret://".freeze

  attr_reader :pid, :pgid, :output

  def initialize(output, verbose: false, deploy: nil)
    @output = output
    @verbose = verbose
    @deploy = deploy
  end

  def execute!(*commands)
    if @verbose
      commands.map! { |c| "echo » #{c.shellescape}\n#{resolve_secrets(c)}" }
    else
      commands.map! { |c| resolve_secrets(c) }
    end
    commands.unshift("set -e")

    execute_command!(commands.join("\n"))
  end

  def stop!(signal)
    system('kill', "-#{signal}", "-#{pgid}") if pgid
  end

  private

  # TODO: pick dynamic secret from just the key
  def resolve_secrets(command)
    deploy_groups = @deploy.try(:stage).try(:deploy_groups) || []
    allowed = {
      environment_permalink: ['global'].concat(deploy_groups.map(&:environment).map(&:permalink)),
      project_permalink: ['global'] << @deploy.try(:project).try(:permalink),
      deploy_group_permalink: ['global'].concat(deploy_groups.map(&:permalink))
    }
    command.gsub(/\b#{SECRET_PREFIX}(#{SecretStorage::SECRET_KEY_REGEX})\b/) do
      key = $1
      parts = SecretStorage.parse_secret_key(key)
      if allowed.all? { |k, v| v.include?(parts.fetch(k)) }
        SecretStorage.read(key, include_secret: true).fetch(:value)
      else
        raise ActiveRecord::RecordNotFound, "Not allowed to access key #{key}"
      end
    end
  end

  def execute_command!(command)
    Tempfile.open('samson-execute') do |f|
      f.write command
      f.flush
      options = {in: '/dev/null', unsetenv_others: true, pgroup: true}

      # http://stackoverflow.com/questions/1401002/trick-an-application-into-thinking-its-stdin-is-interactive-not-a-pipe
      script =
        if RbConfig::CONFIG["target_os"].include?("darwin")
          "script -q /dev/null sh #{f.path}"
        else
          "script -qfec 'sh #{f.path}'"
        end

      Open3.popen2e(whitelisted_env, script, options) do |_stdin, oe, wait_thr|
        @pid = wait_thr.pid

        @pgid = begin
          Process.getpgid(@pid)
        rescue Errno::ESRCH
          nil
        end

        oe.each(256) do |line|
          @output.write line.gsub(/\r?\n/, "\r\n") # script on travis returns \n and \r\n on osx and our servers
        end

        wait_thr.value
      end.success?
    end
  end

  def whitelisted_env
    whitelist = [
      'PATH', 'HOME', 'TMPDIR', 'CACHE_DIR', 'TERM', 'SHELL', # general
      'RBENV_ROOT', 'RBENV_HOOK_PATH', 'RBENV_DIR', # ruby
      'DOCKER_URL', 'DOCKER_REGISTRY' # docker
    ] + ENV['ENV_WHITELIST'].to_s.split(/, ?/)
    ENV.to_h.slice(*whitelist)
  end
end
