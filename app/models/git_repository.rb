class GitRepository
  include ::NewRelic::Agent::MethodTracer

  attr_reader :repository_url, :repository_directory, :last_pulled
  attr_accessor :executor

  # The directory in which repositories should be cached.
  cattr_accessor(:cached_repos_dir, instance_writer: false) do
    Rails.application.config.samson.cached_repos_dir
  end

  def initialize(repository_url:, repository_dir:, executor: nil)
    @repository_url = repository_url
    @repository_directory = repository_dir
    @executor = executor
  end

  def setup!(temp_dir, git_reference)
    raise ArgumentError, "git_reference is required" if git_reference.blank?

    executor.output.write("# Beginning git repo setup\n")
    return false unless update_local_cache!
    return false unless clone!(from: repo_cache_dir, to: temp_dir)
    return false unless checkout!(git_reference, pwd: temp_dir)
    true
  end

  def update_local_cache!
    if locally_cached?
      update!
    else
      clone!(from: repository_url, to: repo_cache_dir, mirror: true)
    end
  end

  def clone!(from: repository_url, to: repo_cache_dir, mirror: false)
    @last_pulled = Time.now if from == repository_url
    command =
      if mirror
        "git -c core.askpass=true clone --mirror #{from} #{to}"
      else
        "git clone #{from} #{to}"
      end
    executor.execute! command
  end
  add_method_tracer :clone!

  def commit_from_ref(git_reference, length: 7)
    return unless ensure_local_cache!
    command = ['git', 'describe', '--long', '--tags', '--all', "--abbrev=#{length || 40}", git_reference]
    return unless output = capture_stdout(*command)
    output.split('-').last.sub(/^g/, '')
  end

  def tag_from_ref(git_reference)
    return unless ensure_local_cache!
    capture_stdout 'git', 'describe', '--tags', git_reference
  end

  def repo_cache_dir
    File.join(cached_repos_dir, @repository_directory)
  end

  def tags
    return unless ensure_local_cache!
    command = ["git", "for-each-ref", "refs/tags", "--sort=-authordate", "--format=%(refname)", "--count=600"]
    return [] unless output = capture_stdout(*command)
    output.gsub! 'refs/tags/', ''
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
  def file_content(file, sha)
    if sha =~ Build::SHA1_REGEX
      (locally_cached? && sha_exist?(sha)) || update_local_cache!
    else
      update_local_cache!
      return unless sha = commit_from_ref(sha, length: nil)
    end
    capture_stdout "git", "show", "#{sha}:#{file}"
  end

  private

  def update!
    @last_pulled = Time.now
    executor.execute!("cd #{repo_cache_dir}", 'git fetch -p')
  end
  add_method_tracer :update!

  def sha_exist?(sha)
    !!capture_stdout("git", "cat-file", "-t", sha)
  end

  def ensure_local_cache!
    locally_cached? || update_local_cache!
  end

  def checkout!(git_reference, pwd: repo_cache_dir)
    executor.execute!("cd #{pwd}", "git checkout --quiet #{git_reference.shellescape}")
  end

  def locally_cached?
    Dir.exist?(repo_cache_dir)
  end

  # success: stdout as string
  # error: nil
  def capture_stdout(*command, dir: repo_cache_dir)
    Dir.chdir(dir) do
      env = {"PATH" => ENV["PATH"], "HOME" => ENV["HOME"]} # safer and also fixes locally running with hub gem
      out = IO.popen(env, command, unsetenv_others: true, err: [:child, :out]) { |io| io.read.strip }
      out if $?.success?
    end
  end
end
