require_relative '../test_helper'

describe GitRepository, :model do

  let(:repository_url) { Dir.mktmpdir }
  let(:project) { Project.create!(name: 'test_project', repository_url: repository_url) }
  let(:repo_dir) { File.join(GitRepository.cached_repos_dir, project.repository_directory) }

  it 'validates that the parameters are valid when creating a repository' do
    err = -> { GitRepository.new(repository_url: nil, repository_dir: repo_dir) }.must_raise RuntimeError
    err.message.must_equal 'Invalid repository url!'
    err = -> { GitRepository.new(repository_url: repository_url, repository_dir: nil) }.must_raise RuntimeError
    err.message.must_equal 'Invalid repository directory!'
  end

  it 'checks that the project repository is pointing to the correct url and directory' do
    repo = project.repository
    repo.kind_of? GitRepository
    repo.repository_url.must_equal project.repository_url
    repo.repository_directory.must_equal project.repository_directory
  end

  after(:each) do
    FileUtils.rm_rf(repository_url)
    FileUtils.rm_rf(repo_dir)
    FileUtils.rm_rf(project.repository.repo_cache_dir)
  end

  it 'returns the tags repository' do
    create_repo_with_tags
    output = StringIO.new
    executor = TerminalExecutor.new(output)
    repository = project.repository
    repository.setup!(output, executor)
    repository.tags.to_a.must_equal %w(v1 )
  end

  it 'returns an empty set of tags' do
    create_repo_without_tags
    output = StringIO.new
    executor = TerminalExecutor.new(output)
    repository = project.repository
    repository.setup!(output, executor)
    repository.tags.must_equal []
  end

  it 'returns the branches of the repository' do
    create_repo_with_an_additional_branch
    output = StringIO.new
    executor = TerminalExecutor.new(output)
    repository = project.repository
    repository.setup!(output, executor)
    repository.branches.to_a.must_equal %w(master test_user/test_branch)
  end

  it 'sets the repository to the provided git reference' do
    create_repo_with_an_additional_branch
    output = StringIO.new
    executor = TerminalExecutor.new(output)
    repository = project.repository
    temp_dir = Dir.mktmpdir
    repository.setup!(output, executor, temp_dir, 'test_user/test_branch').must_equal true
    Dir.chdir(temp_dir) do
      `git rev-parse --abbrev-ref HEAD`.strip.must_equal 'test_user/test_branch'
    end
  end

  it 'returns false if we try to setup the repository to a particular git reference and no temp_dir is given' do
    create_repo_with_an_additional_branch
    output = StringIO.new
    executor = TerminalExecutor.new(output)
    repository = project.repository
    repository.setup!(output, executor, nil, 'master').must_equal false
  end

  def execute_on_remote_repo(cmds)
    `exec 2> /dev/null; cd #{repository_url}; #{cmds}`
  end

  def create_repo_with_tags
    execute_on_remote_repo <<-SHELL
      git init
      git config user.email "test@example.com"
      git config user.name "Test User"
      echo monkey > foo
      git add foo
      git commit -m "initial commit"
      git tag v1
    SHELL
  end

  def create_repo_without_tags
    execute_on_remote_repo <<-SHELL
      git init
      git config user.email "test@example.com"
      git config user.name "Test User"
      echo monkey > foo
      git add foo
      git commit -m "initial commit"
    SHELL
  end

  def create_repo_with_an_additional_branch
    execute_on_remote_repo <<-SHELL
      git init
      git config user.email "test@example.com"
      git config user.name "Test User"
      echo monkey > foo
      git add foo
      git commit -m "initial commit"
      git checkout -b test_user/test_branch
    SHELL
  end

end

