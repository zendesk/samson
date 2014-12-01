require_relative '../test_helper'

describe ReferencesService, :model do

  let!(:repository_url) { Dir.mktmpdir }
  let!(:project) { Project.create!(name: 'test_project', repository_url: repository_url) }
  let!(:repo_dir) { File.join(GitRepository.cached_repos_dir, project.repository_directory) }

  before(:all) do
    execute_on_remote_repo <<-SHELL
      git init
      git config user.email "test@example.com"
      git config user.name "Test User"
      echo monkey > foo
      git add foo
      git commit -m "initial commit"
      git tag v1
      git checkout -b test_user/test_branch
    SHELL
  end

  after do
    FileUtils.rm_rf(repository_url)
    FileUtils.rm_rf(repo_dir)
    FileUtils.rm_rf(project.repository.repo_cache_dir)
  end

  it 'returns a sorted set of tags and branches' do
    ReferencesService.new(project).find_git_references.must_equal %w(v1 master test_user/test_branch )
  end

  it 'returns a sorted set of tags and branches from cached repo' do
    ReferencesService.new(project).get_references_from_cached_repo.must_equal %w(v1 master test_user/test_branch )
  end

  it 'returns a sorted set of tags and branches from remote repo' do
    ReferencesService.new(project).get_references_from_ls_remote.must_equal %w(v1 master test_user/test_branch )
  end

  it 'the ttl and hit threshold should always return an integer' do
    Rails.application.config.samson.stubs(:references_cache_ttl).returns('10')
    Rails.application.config.samson.stubs(:references_hit_threshold).returns('2')
    references_service = ReferencesService.new(project)
    references_service.references_hit_threshold.must_equal 2
    references_service.references_ttl.must_equal 10
  end

  def execute_on_remote_repo(cmds)
    `exec 2> /dev/null; cd #{repository_url}; #{cmds}`
  end

end
