# frozen_string_literal: true
# Responsible for all git knowledge of a repo
# Caches a local mirror (not a full checkout) and creates a workspace when deploying
class GitRepository
  include ::NewRelic::Agent::MethodTracer

  attr_accessor :executor # others set this to listen in on commands being executed

  # The directory in which repositories should be cached.
  # TODO: find out and comment why this needs to be settable or make read-only self. method
  cattr_accessor(:cached_repos_dir, instance_writer: false) do
    Rails.application.config.samson.cached_repos_dir
  end

  def initialize(repository_url:, repository_dir:, executor: nil)
    @repository_url = repository_url
    @repository_directory = repository_dir
    @executor = executor || TerminalExecutor.new(StringIO.new)
  end

  def checkout_workspace(work_dir, git_reference)
    raise ArgumentError, "git_reference is required" if git_reference.blank?

    executor.output.write("# Beginning git repo setup\n")

    ensure_mirror_current &&
    create_workspace(work_dir) &&
    checkout(git_reference, work_dir) &&
    checkout_submodules(work_dir)
  end

  # @return [nil, sha1]
  def commit_from_ref(git_reference)
    return unless ensure_mirror_current
    command = ['git', 'rev-parse', "#{git_reference}^{commit}"]
    capture_stdout(*command)
  end

  # @return [nil, tag-sha or tag]
  def fuzzy_tag_from_ref(git_reference)
    return unless ensure_mirror_current
    capture_stdout 'git', 'describe', '--tags', git_reference
  end

  # used by other parts to store extra files in subfolders
  def repo_cache_dir
    File.join(cached_repos_dir, repository_directory)
  end

  def tags
    return unless ensure_mirror_current
    command = ["git", "for-each-ref", "refs/tags", "--sort=-authordate", "--format=%(refname)", "--count=600"]
    return [] unless output = capture_stdout(*command)
    output = output.gsub 'refs/tags/', ''
    output.split("\n")
  end

  def branches
    return unless ensure_mirror_current
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

  # updates the repo only if sha is not found, to not pull unnecessarily
  # @return [content, nil]
  def file_content(file, sha, pull: true)
    if !pull
      return unless mirrored?
    elsif sha =~ Build::SHA1_REGEX
      (mirrored? && sha_exist?(sha)) || ensure_mirror_current
    else
      ensure_mirror_current
    end
    capture_stdout "git", "show", "#{sha}:#{file}"
  end

  private

  attr_reader :repository_url, :repository_directory

  # @returns [true, false]
  def ensure_mirror_current
    return @mirror_current unless @mirror_current.nil?
    @mirror_current = exclusive { (mirrored? ? update! : clone!) }
  end

  # makes sure that only 1 repository is doing mirror/clone at any given time
  # also print to the job output when we are waiting for a lock so user knows to be patient
  # @returns [block result, false on lock timeout]
  def exclusive(timeout: 10.minutes)
    log_wait = proc do |owner|
      if Rails.env.test? || (Time.now.to_i % 10).zero?
        executor.output.write("Waiting for repository lock for #{owner}\n")
      end
    end
    MultiLock.lock(repo_cache_dir, outside_caller, timeout: timeout, failed_to_lock: log_wait) { return yield }
  end

  # first outside location that called us
  # going from bottom to top to avoid finding monkey-patches
  def outside_caller
    callstack = caller
    if first_inside = callstack.rindex { |l| l.include?(__FILE__) }
      callstack[first_inside + 1].split("/").last
    else
      "Unknown"
    end
  end

  def clone!
    executor.execute "git -c core.askpass=true clone --mirror #{repository_url} #{repo_cache_dir}"
  end
  add_method_tracer :clone!

  def create_workspace(temp_dir)
    executor.execute "git clone #{repo_cache_dir} #{temp_dir}"
  end
  add_method_tracer :create_workspace

  def update!
    executor.execute("cd #{repo_cache_dir}", 'git fetch -p --depth=50')
  end
  add_method_tracer :update!

  def sha_exist?(sha)
    !!capture_stdout("git", "cat-file", "-t", sha)
  end

  def checkout(git_reference, pwd)
    executor.execute("cd #{pwd}", "git checkout --quiet #{git_reference.shellescape}")
  end

  def checkout_submodules(pwd)
    return true unless File.exist? "#{pwd}/.gitmodules"

    recursive_flag = " --recursive" if git_supports_recursive_flag?
    executor.execute(
      "cd #{pwd}",
      "git submodule sync#{recursive_flag}",
      "git submodule update --init --recursive"
    )
  end

  def git_supports_recursive_flag?
    Samson::GitInfo.version >= Gem::Version.new("1.8.1")
  end

  def mirrored?
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
