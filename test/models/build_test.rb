require_relative '../test_helper'

describe Build do
  include GitRepoTestHelper

  describe 'validations' do
    let(:project) { Project.new(id: 99999, name: 'test_project', repository_url: repo_temp_dir) }
    let(:repository) { project.repository }
    let(:cached_repo_dir) { File.join(GitRepository.cached_repos_dir, project.repository_directory) }
    let(:git_tag) { 'test_tag' }

    before do
      create_repo_with_tags(git_tag)
    end

    after do
      FileUtils.rm_rf(repo_temp_dir)
      FileUtils.rm_rf(repository.repo_cache_dir)
      FileUtils.rm_rf(cached_repo_dir)
    end

    it 'should validate git sha' do
      Dir.chdir(repo_temp_dir) do
        assert_valid(Build.new(project: project, git_sha: current_commit))
        refute_valid(Build.new(project: project, git_sha: '0123456789012345678901234567890123456789'))
        refute_valid(Build.new(project: project, git_sha: 'This is a string of 40 characters.......'))
        refute_valid(Build.new(project: project, git_sha: 'abc'))
      end
    end

    it 'should validate container sha' do
      assert_valid(Build.new(project: project, docker_sha: '0fbc33a0bfe9dcb5a17e26b9c319cce9d86ede14'))
      refute_valid(Build.new(project: project, docker_sha: 'This is a string of 40 characters.......'))
      refute_valid(Build.new(project: project, docker_sha: 'abc'))
    end

    it 'should validate git_ref' do
      assert_valid(Build.new(project: project, git_ref: 'master'))
      assert_valid(Build.new(project: project, git_ref: git_tag))
      Dir.chdir(repo_temp_dir) do
        assert_valid(Build.new(project: project, git_ref: current_commit))
      end
      refute_valid(Build.new(project: project, git_ref: 'some_tag_i_made_up'))
    end
  end

  describe 'successful?' do
    let(:build) { builds(:staging) }

    it 'returns true when all successful' do
      build.statuses.create!(source: 'Jenkins', status: BuildStatus::SUCCESSFUL)
      build.statuses.create!(source: 'Travis',  status: BuildStatus::SUCCESSFUL)
      assert build.successful?
    end

    it 'returns false when there is a failure' do
      build.statuses.create!(source: 'Jenkins', status: BuildStatus::SUCCESSFUL)
      build.statuses.create!(source: 'Travis',  status: BuildStatus::FAILED)
      refute build.successful?
    end

    it 'returns false when there is a pending status' do
      build.statuses.create!(source: 'Jenkins', status: BuildStatus::SUCCESSFUL)
      build.statuses.create!(source: 'Travis',  status: BuildStatus::PENDING)
      refute build.successful?
    end
  end
end
