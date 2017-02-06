# frozen_string_literal: true
class GitRepository
  include ::NewRelic::Agent::MethodTracer

  attr_reader :repository_url, :repository_directory, :last_pulled
  attr_writer :executor

  # The directory in which repositories should be cached.
  cattr_accessor(:cached_repos_dir, instance_writer: false) do
    Rails.application.config.samson.cached_repos_dir
  end

  def initialize(repository_url:, repository_dir:, executor: nil)
    @repository_url = repository_url
    @repository_directory = repository_dir
    @executor = executor
  end

  def checkout_workspace(temp_dir, git_reference)
    raise ArgumentError, "git_reference is required" if git_reference.blank?

    executor.output.write("# Beginning git repo setup\n")
    return false unless @last_pulled || update_local_cache!
    return false unless create_workspace(temp_dir)
    return false unless checkout!(git_reference, temp_dir)
    return false unless checkout_submodules!(temp_dir)
    true
  end

  # FIXME: always use exclusive
  # atm we use exclusive only from a few placed that call this
  def update_local_cache!
    @last_pulled = Time.now
    if locally_cached?
      update!
    else
      clone!
    end
  end

  # @return [nil, sha1]
  def commit_from_ref(git_reference)
    return unless ensure_local_cache!
    command = ['git', 'rev-parse', "#{git_reference}^{commit}"]
    capture_stdout(*command)
  end

  # @return [nil, tag-sha or tag]
  def fuzzy_tag_from_ref(git_reference)
    return unless update_local_cache!
    capture_stdout 'git', 'describe', '--tags', git_reference
  end

  def repo_cache_dir
    File.join(cached_repos_dir, @repository_directory)
  end

  def tags
    return unless ensure_local_cache!
    command = ["git", "for-each-ref", "refs/tags", "--sort=-authordate", "--format=%(refname)", "--count=600"]
    return [] unless output = capture_stdout(*command)
    output = output.gsub 'refs/tags/', ''
    output.split("\n")
  end

  def branches
    return unless ensure_local_cache!
    return [] unless output = capture_stdout('git', 'branch', '--list', '--no-column')
    output.delete!('* ')
    output.split("\n")
  end

  def clean!
    FileUtils.rm_rf(repo_cache_dir)
  end
  add_method_tracer :clean!

  def valid_url?
    return false if repository_url.blank?
    output = capture_stdout "git", "-c", "core.askpass=true", "ls-remote", "-h", repository_url, dir: '.'
    Rails.logger.error("Repository Path '#{repository_url}' is unreachable") unless output
    !!output
  end

  def executor
    @executor ||= TerminalExecutor.new(StringIO.new)
  end

  # will update the repo if sha is not found
  def file_content(file, sha, pull: true)
    if !pull
      return unless locally_cached?
    elsif sha =~ Build::SHA1_REGEX
      (locally_cached? && sha_exist?(sha)) || update_local_cache!
    else
      update_local_cache!
    end
    capture_stdout "git", "show", "#{sha}:#{file}"
  end

  # @return [true, false] if it could lock
  def exclusive(output: StringIO.new, holder:, timeout: 10.minutes)
    error_callback = proc do |owner|
      output.write("Waiting for repository lock for #{owner}\n") if (Time.now.to_i % 10).zero?
    end
    MultiLock.lock(repo_cache_dir, holder, timeout: timeout, failed_to_lock: error_callback) { yield self }
  end

  private

  def clone!
    executor.execute! "git -c core.askpass=true clone --mirror #{repository_url} #{repo_cache_dir}"
  end
  add_method_tracer :clone!

  def create_workspace(temp_dir)
    executor.execute! "git clone #{repo_cache_dir} #{temp_dir}"
  end
  add_method_tracer :create_workspace

  def update!
    executor.execute!("cd #{repo_cache_dir}", 'git fetch -p')
  end
  add_method_tracer :update!

  def sha_exist?(sha)
    !!capture_stdout("git", "cat-file", "-t", sha)
  end

  def ensure_local_cache!
    locally_cached? || update_local_cache!
  end

  def checkout!(git_reference, pwd)
    executor.execute!("cd #{pwd}", "git checkout --quiet #{git_reference.shellescape}")
  end

  def checkout_submodules!(pwd)
    return true unless File.exist? "#{pwd}/.gitmodules"

    recursive_flag = " --recursive" if git_supports_recursive_flag?
    executor.execute!(
      "cd #{pwd}",
      "git submodule sync#{recursive_flag}",
      "git submodule update --init --recursive"
    )
  end

  def git_supports_recursive_flag?
    Samson::GitInfo.version >= Gem::Version.new("1.8.1")
  end

  def locally_cached?
    Dir.exist?(repo_cache_dir)
  end

  # success: stdout as string
  # error: nil
  def capture_stdout(*command, dir: repo_cache_dir)
    Dir.chdir(dir) do
      success, output = Samson::CommandExecutor.execute(
        *command,
        whitelist_env: ['HOME', 'PATH'],
        timeout: 30.minutes,
        err: '/dev/null'
      )
      output.strip if success
    end
  end
end
