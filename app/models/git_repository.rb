class GitRepository
  include ::NewRelic::Agent::MethodTracer

  attr_reader :repository_url, :repository_directory
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
    raise ArgumentError.new("git_reference is required") if git_reference.blank?

    executor.output.write("# Beginning git repo setup\n")
    return false unless setup_local_cache!
    return false unless clone!(from: repo_cache_dir, to: temp_dir)
    return false unless checkout!(git_reference, pwd: temp_dir)
    true
  end

  def setup_local_cache!
    if locally_cached?
      update!
    else
      clone!(from: repository_url, to: repo_cache_dir, mirror: true)
    end
  end

  def clone!(from: repository_url, to: repo_cache_dir, mirror: false)
    if mirror
      executor.execute!("git -c core.askpass=true clone --mirror #{from} #{to}")
    else
      executor.execute!("git clone #{from} #{to}")
    end
  end
  add_method_tracer :clone!

  def update!
    executor.execute!("cd #{repo_cache_dir}", 'git fetch -p')
  end
  add_method_tracer :update!

  def commit_from_ref(git_reference, length: 7)
    Dir.chdir(repo_cache_dir) do
      description = IO.popen(['git', 'describe', '--long', '--tags', '--all', "--abbrev=#{length || 40}", git_reference], err: [:child, :out]) do |io|
        io.read.strip
      end

      return nil unless $?.success?

      description.split('-').last.sub(/^g/, '')
    end
  end

  def tag_from_ref(git_reference)
    Dir.chdir(repo_cache_dir) do
      tag = IO.popen(['git', 'describe', '--tags', git_reference], err: [:child, :out]) do |io|
        io.read.strip
      end

      tag if $?.success?
    end
  end

  def repo_cache_dir
    File.join(cached_repos_dir, @repository_directory)
  end

  def tags
    cmd = "git for-each-ref refs/tags --sort=-authordate --format='%(refname)' --count=600 | sed 's/refs\\/tags\\///g'"
    success, output = run_single_command(cmd) { |line| line.strip }
    success ? output : []
  end

  def branches
    cmd = 'git branch --list --no-color --no-column'
    success, output = run_single_command(cmd) { |line| line.sub('*', '').strip }
    success ? output : []
  end

  def clean!
    FileUtils.rm_rf(repo_cache_dir)
  end
  add_method_tracer :clean!

  def valid_url?
    return false if repository_url.blank?

    cmd = "git -c core.askpass=true ls-remote -h #{repository_url}"
    valid, output = run_single_command(cmd, pwd: '.')
    Rails.logger.error("Repository Path '#{repository_url}' is invalid: #{output}") unless valid
    valid
  end

  def downstream_commit?(old_commit, new_commit)
    return true if old_commit == new_commit
    cmd = "git merge-base --is-ancestor #{old_commit} #{new_commit}"
    status, output = run_single_command(cmd) { |l| l }
    !status && !output[0].to_s.include?("fatal")
  end

  def executor
    @executor ||= TerminalExecutor.new(StringIO.new)
  end

  def file_changed?(sha1, sha2, file)
    executor.execute!("cd #{pwd}", "git diff --quiet --name-only #{sha1}..#{sha2} #{file}")
  end

  private

  def checkout!(git_reference, pwd: repo_cache_dir)
    executor.execute!("cd #{pwd}", "git checkout --quiet #{git_reference.shellescape}")
  end

  def locally_cached?
    Dir.exist?(repo_cache_dir)
  end

  def run_single_command(command, pwd: repo_cache_dir)
    tmp_executor = TerminalExecutor.new(StringIO.new)
    success = tmp_executor.execute!("cd #{pwd}", command)
    result = tmp_executor.output.string.lines.map { |line| yield line if block_given? }.uniq.sort
    [success, result]
  end
end
