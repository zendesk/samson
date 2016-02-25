require_relative '../test_helper'

describe DeployService do
  include GitRepoTestHelper

  let(:tmp_dir) { Dir.mktmpdir }
  let(:project_repo_url) { repo_temp_dir }
  let(:git_tag) { 'v123' }
  let(:project) { projects(:test).tap { |p| p.repository_url = project_repo_url } }

  let(:build) { project.builds.create(git_ref: git_tag) }
  let(:service) { DockerBuilderService.new(build) }

  let(:docker_image_id) { '2d2b0b3204b0166435c3d96d0b27d0ad2083e5e040192632c58eeb9491d6bfaa' }
  let(:docker_image_json) do
    {
      'Id' => docker_image_id
    }
  end
  let(:mock_docker_image) { stub(json: docker_image_json) }

  before { create_repo_with_tags(git_tag) }

  describe '#build_image' do
    before do
      Docker::Image.expects(:build_from_dir).returns(mock_docker_image)
      service.build_image(tmp_dir)
    end

    it 'writes the REVISION file' do
      revision_filepath = File.join(tmp_dir, 'REVISION')
      assert File.exists?(revision_filepath)
      assert_equal(build.git_sha, File.read(revision_filepath))
    end

    it 'updates the Build object' do
      assert_equal(docker_image_id, build.docker_image_id)
    end
  end

  describe '#push_image' do
    let(:repo_digest) { 'sha256:5f1d7c7381b2e45ca73216d7b06004fdb0908ed7bb8786b62f2cdfa5035fde2c' }
    let(:push_output) { [
      [{status: "pushing image to repo..."}.to_json],
      [{status: "completed push."}.to_json],
      [{status: "Frobinating..."}.to_json],
      [{status: "Digest: #{repo_digest}"}.to_json],
      [{status: "Done"}.to_json]
    ] }

    before do
      mock_docker_image.stubs(:push)
      mock_docker_image.stubs(:tag)
      build.docker_image = mock_docker_image
    end

    it 'sets the values on the build' do
      mock_docker_image.expects(:push).multiple_yields(*push_output).twice
      build.label = "Version 123"
      service.push_image(nil)
      assert_equal('version-123', build.docker_ref)
      assert_equal("#{project.docker_repo}@#{repo_digest}", build.docker_repo_digest)
    end

    it 'saves docker output to the buffer' do
      mock_docker_image.expects(:push).multiple_yields(*push_output).once
      mock_docker_image.expects(:tag).once
      service.push_image(nil)
      assert_includes(service.output_buffer.to_s, 'Frobinating...')
      assert_equal('latest', build.docker_ref)
    end

    it 'uses the tag passed in' do
      mock_docker_image.expects(:tag).twice
      service.push_image('my-test')
      assert_equal('my-test', build.docker_ref)
    end

    it 'always adds the latest tag on top of the one specified' do
      mock_docker_image.expects(:tag).with(has_entry(tag: 'my-test')).with(has_entry(tag: 'latest'))
      mock_docker_image.expects(:push).with(service.send(:registry_credentials), tag: 'latest', force: true)
      service.push_image('my-test')
    end
  end
end
