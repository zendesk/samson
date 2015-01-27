class GitRepository

  attr_reader :repository_url, :repository_directory

  # The directory in which repositories should be cached.
  cattr_accessor(:cached_repos_dir, instance_writer: false) do
    Rails.application.config.samson.cached_repos_dir
  end

  def initialize(repository_url:, repository_dir:)
    @repository_url = repository_url
    @repository_directory = repository_dir
  end

  def setup!(executor, temp_dir, git_reference)
    executor.output.write("Beginning git repo setup\n")
    return false unless update!(executor: executor)
    return false unless clone!(executor: executor, from: repo_cache_dir, to: temp_dir)
    return false unless checkout!(executor: executor, pwd: temp_dir, git_reference: git_reference.shellescape)
    true
  end

  def clone!(executor: TerminalExecutor.new(StringIO.new), from: repository_url, to: repo_cache_dir, mirror: false)
    return executor.execute!("git -c core.askpass=true clone --mirror #{from} #{to}") if mirror
    executor.execute!("git clone #{from} #{to}")
  end

  def update!(executor: TerminalExecutor.new(StringIO.new), pwd: repo_cache_dir)
    executor.execute!("cd #{pwd}", 'git fetch -ap')
  end

  def checkout!(executor: TerminalExecutor.new(StringIO.new), pwd: repo_cache_dir, git_reference:)
    executor.execute!("cd #{pwd}", "git checkout #{git_reference}")
  end

  def commit_from_ref(git_reference)
    description = Dir.chdir(repo_cache_dir) do
      IO.popen(['git', 'describe', '--long', '--tags', '--all', git_reference]) do |io|
        io.read.strip
      end
    end

    description.split('-').last.sub(/^g/, '')
  end

  def repo_cache_dir
    File.join(cached_repos_dir, @repository_directory)
  end

  def locally_cached?
    Dir.exist?(repo_cache_dir)
  end

  def tags
    cmd = 'git describe --tags --abbrev=0 `git rev-list --tags --max-count=600`'
    run_single_command(cmd) { |line| line.strip }
  end

  def branches
    cmd = 'git branch --no-color --list'
    run_single_command(cmd) { |line| line.sub('*', '').strip }
  end

  def clean!
    FileUtils.rm_rf(repo_cache_dir)
  end

  def git_dir?(repo_dir)
    Dir.exist?("#{repo_dir}/.git") || File.exist?("#{repo_dir}/HEAD")
  end

  def valid_url?
    cmd = "git -c core.askpass=true ls-remote -h #{repository_url}"
    output = StringIO.new
    executor = TerminalExecutor.new(output)
    return true if executor.execute!(cmd)
    Rails.logger.error("#{repository_url} is invalid: #{output.string}")
    false
  end

  private

  def run_single_command(command, pwd: repo_cache_dir)
      output = StringIO.new
      executor = TerminalExecutor.new(output)
      success = executor.execute!("cd #{pwd}", command)
      return [] unless success
      output.string.lines.map { |line| yield line if block_given? }.uniq.sort
  end

end
