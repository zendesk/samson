require_relative '../test_helper'

describe Build do
  include GitRepoTestHelper

  let(:project) { Project.new(id: 99999, name: 'test_project', repository_url: repo_temp_dir) }
  let(:sha_digest) { 'cbbf2f9a99b47fc460d422812b6a5adff7dfee951d8fa2e4a98caa0382cfbdbf' }

  def valid_build(attributes = {})
    Build.new(attributes.reverse_merge(project: project, git_ref: 'master'))
  end

  describe 'validations' do
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
        assert_valid(valid_build(git_ref: nil, git_sha: current_commit))
        refute_valid(valid_build(git_ref: nil, git_sha: '0123456789012345678901234567890123456789'))
        refute_valid(valid_build(git_ref: nil, git_sha: 'This is a string of 40 characters.......'))
        refute_valid(valid_build(git_ref: nil, git_sha: 'abc'))
      end
    end

    it 'should validate container sha' do
      assert_valid(valid_build(docker_image_id: sha_digest))
      refute_valid(valid_build(docker_image_id: 'This is a string of 64 characters...............................'))
      refute_valid(valid_build(docker_image_id: 'abc'))
    end

    it 'should validate git_ref' do
      assert_valid(valid_build(git_ref: 'master'))
      assert_valid(valid_build(git_ref: git_tag))
      refute_valid(Build.new(project: project))
      Dir.chdir(repo_temp_dir) do
        assert_valid(valid_build(git_ref: current_commit))
      end
      refute_valid(valid_build(git_ref: 'some_tag_i_made_up'))
    end
  end

  describe 'create' do
    let(:project) { projects(:test) }

    before do
      create_repo_without_tags
      project.repository_url = repo_temp_dir
    end

    it 'increments the build number' do
      biggest_build_num = project.builds.maximum(:number) || 0
      build = project.builds.create!(git_ref: 'master')
      assert_valid(build)
      assert_equal(biggest_build_num + 1, build.number)
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

  describe '#docker_image=' do
    let(:build) { valid_build }
    let(:docker_image_id) { '2d2b0b3204b0166435c3d96d0b27d0ad2083e5e040192632c58eeb9491d6bfaa' }
    let(:docker_image_json) do
      {
        'Id' => docker_image_id
      }
    end
    let(:mock_docker_image) { stub(json: docker_image_json) }

    it 'updates the docker_image_id' do
      build.docker_image = mock_docker_image
      assert_equal(docker_image_id, build.docker_image_id)
      assert_equal(mock_docker_image, build.docker_image)
    end
  end
end
