require_relative '../test_helper'

describe GitRepository do
  let(:repository_url) { Dir.mktmpdir }
  let(:project) { Project.new(id: 99999, name: 'test_project', repository_url: repository_url) }
  let(:repository) { project.repository }
  let(:executor) { TerminalExecutor.new(StringIO.new) }
  let(:repo_dir) { File.join(GitRepository.cached_repos_dir, project.repository_directory) }

  after do
    FileUtils.rm_rf(repository_url)
    FileUtils.rm_rf(repo_dir)
    FileUtils.rm_rf(repository.repo_cache_dir)
  end

  it 'checks that the project repository is pointing to the correct url and directory' do
    repository.is_a? GitRepository
    repository.repository_url.must_equal project.repository_url
    repository.repository_directory.must_equal project.repository_directory
  end

  it 'should clone a repository' do
    Dir.mktmpdir do |dir|
      create_repo_with_tags
      repository.clone!(from: repository_url, to: dir)
      Dir.exist?(dir).must_equal true
    end
  end

  describe "#update!" do
    it 'updates the repository' do
      create_repo_with_tags
      repository.clone!.must_equal(true)
      Dir.chdir(repository.repo_cache_dir) { number_of_commits.must_equal(1) }
      execute_on_remote_repo <<-SHELL
        echo monkey > foo2
        git add foo2
        git commit -m "second commit"
      SHELL
      repository.update!.must_equal(true)
      Dir.chdir(repository.repo_cache_dir) do
        update_workspace
        number_of_commits.must_equal(2)
      end
    end

    it 'fails when its cache was removed' do
      create_repo_with_tags
      repository.update!.must_equal(false)
    end
  end

  it 'should switch to a different branch' do
    create_repo_with_an_additional_branch
    repository.clone!.must_equal(true)
    repository.send(:checkout!, git_reference: 'master').must_equal(true)
    Dir.chdir(repository.repo_cache_dir) { current_branch.must_equal('master') }
    repository.send(:checkout!, git_reference: 'test_user/test_branch').must_equal(true)
    Dir.chdir(repository.repo_cache_dir) { current_branch.must_equal('test_user/test_branch') }
  end

  describe "#commit_from_ref" do
    it 'returns the short commit id' do
      create_repo_with_tags
      repository.clone!
      repository.commit_from_ref('master').must_match /^[0-9a-f]{7}$/
    end
  end

  describe "#tag_from_ref" do
    it 'returns nil when repo has no tags' do
      create_repo_without_tags
      repository.clone!
      repository.tag_from_ref('master').must_be_nil
    end

    it 'returns the closest matching tag' do
      create_repo_with_tags
      execute_on_remote_repo <<-SHELL
        echo update > foo
        git commit -a -m 'untagged commit'
      SHELL
      repository.clone!
      repository.tag_from_ref('master~').must_equal 'v1'
      repository.tag_from_ref('master').must_match /^v1-1-g[0-9a-f]{7}$/
    end
  end

  describe "#tags" do
    it 'returns the tags repository' do
      create_repo_with_tags
      repository.clone!(executor: TerminalExecutor.new(StringIO.new), mirror: true)
      repository.tags.to_a.must_equal %w(v1 )
    end

    it 'returns an empty set of tags' do
      create_repo_without_tags
      repository.clone!(executor: TerminalExecutor.new(StringIO.new), mirror: true)
      repository.tags.must_equal []
    end
  end

  describe "#branches" do
    it 'returns the branches of the repository' do
      create_repo_with_an_additional_branch
      repository.clone!(executor: TerminalExecutor.new(StringIO.new), mirror: true)
      repository.branches.to_a.must_equal %w(master test_user/test_branch)
    end
  end

  describe "#valid_url?" do
    it 'validates the repo url' do
      create_repo_without_tags
      repository.valid_url?.must_equal true
    end

    it 'invalidates the repo url without repo' do
      repository.valid_url?.must_equal false
    end
  end

  describe "#setup!" do
    it 'creates a repository' do
      create_repo_with_an_additional_branch
      Dir.mktmpdir do |temp_dir|
        assert repository.setup!(executor, temp_dir, 'test_user/test_branch')
        Dir.chdir(temp_dir) { current_branch.must_equal('test_user/test_branch') }
      end
    end

    it 'updates an existing repository to a branch' do
      create_repo_with_an_additional_branch
      Dir.mktmpdir do |temp_dir|
        repository.send(:clone!, executor: executor, mirror: true)
        assert repository.setup!(executor, temp_dir, 'test_user/test_branch')
        Dir.chdir(temp_dir) { current_branch.must_equal('test_user/test_branch') }
      end
    end
  end

  describe "#clean!" do
    it 'removes a repository' do
      create_repo_without_tags
      Dir.mktmpdir do |temp_dir|
        assert repository.setup!(executor, temp_dir, 'master')
        Dir.exist?(repository.repo_cache_dir).must_equal true
        repository.clean!
        Dir.exist?(repository.repo_cache_dir).must_equal false
      end
    end

    it 'does not fail when repo is missing' do
      repository.clean!
    end
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
      echo monkey > foo2
      git add foo2
      git commit -m "branch commit"
      git checkout master
    SHELL
  end

  def current_branch
    `git rev-parse --abbrev-ref HEAD`.strip
  end

  def number_of_commits
    `git rev-list HEAD --count`.strip.to_i
  end

  def update_workspace
    `git pull`.strip
  end
end
