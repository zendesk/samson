class GitRepository

  attr_reader :repository_url, :repository_directory

  # The directory in which repositories should be cached.
  cattr_accessor(:cached_repos_dir, instance_writer: false) do
    Rails.application.config.samson.cached_repos_dir
  end

  def initialize(repository_url:, repository_dir:)
    raise 'Invalid repository url!' unless repository_url
    raise 'Invalid repository directory!' unless repository_dir
    @repository_url = repository_url
    @repository_directory = repository_dir
  end

  def setup!(output, executor, temp_dir=nil, git_reference=nil)
    output.write("Beginning git repo setup\n")

    commands = [
      <<-SHELL
        if [ -d #{repo_cache_dir} ]
          then cd #{repo_cache_dir} && git fetch -ap
        else
          git -c core.askpass=true clone --mirror #{@repository_url} #{repo_cache_dir}
        fi
      SHELL
    ]

    if git_reference and !temp_dir
      output.write("Cannot setup the repository to git reference as temporary directory was not provided\n")
      return false
    end

    if git_reference
      commands += [
        "git clone #{repo_cache_dir} #{temp_dir}",
        "cd #{temp_dir}",
        "git checkout --quiet #{git_reference.shellescape}"
      ]
    end
    executor.execute!(*commands)
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

  def is_locally_cached?
    Dir.exist?(repo_cache_dir)
  end

  def tags
    Dir.chdir(repo_cache_dir) do
      output = StringIO.new
      executor = TerminalExecutor.new(output)
      command = 'git describe --tags --abbrev=0 `git rev-list --tags --max-count=600`'
      success = executor.execute!(command)
      return [] unless success
      SortedSet.new(output.string.lines.map { |line| line.chomp.strip })
    end
  end

  def branches
    Dir.chdir(repo_cache_dir) do
      output = StringIO.new
      executor = TerminalExecutor.new(output)
      executor.execute!('git branch --no-color')
      SortedSet.new(output.string.lines.map { |line| line.sub('*', '').chomp.strip })
    end
  end

  def clean!
    FileUtils.rm_rf(repo_cache_dir)
  end

end
