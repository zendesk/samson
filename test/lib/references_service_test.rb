require_relative '../test_helper'

SingleCov.covered!

describe ReferencesService do
  let!(:repository_url) do
    tmp = Dir.mktmpdir
    cmds = <<-SHELL
      git init
      git config user.email "test@example.com"
      git config user.name "Test User"
      echo monkey > foo
      git add foo
      git commit -m "initial commit"
      git tag v1
      git checkout -b test_user/test_branch
    SHELL
    execute_on_remote_repo(tmp, cmds)
    tmp
  end

  let!(:project) { Project.create!(name: 'test_project', repository_url: repository_url) }

  before do
    project.repository.clone!(mirror: true)
  end

  it 'returns a sorted set of tags and branches' do
    ReferencesService.new(project).find_git_references.must_equal %w[v1 master test_user/test_branch ]
  end

  it 'returns a sorted set of tags and branches from cached repo' do
    ReferencesService.new(project).send(:references_from_cached_repo).must_equal %w[v1 master test_user/test_branch]
  end

  it 'the ttl threshold should always return an integer' do
    Rails.application.config.samson.stubs(:references_cache_ttl).returns('10')
    references_service = ReferencesService.new(project)
    references_service.send(:references_ttl).must_equal 10
  end

  def execute_on_remote_repo(directory, cmds)
    `exec 2> /dev/null; cd #{directory}; #{cmds}`
  end

  after do
    FileUtils.rm_rf(repository_url)
    FileUtils.rm_rf(project.repository.clean!)
  end
end
