require_relative '../test_helper'

SingleCov.covered! uncovered: 20

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
    end

    it 'writes the REVISION file' do
      service.build_image(tmp_dir)
      revision_filepath = File.join(tmp_dir, 'REVISION')
      assert File.exist?(revision_filepath)
      assert_equal(build.git_sha, File.read(revision_filepath))
    end

    it 'updates the Build object' do
      service.build_image(tmp_dir)
      assert_equal(docker_image_id, build.docker_image_id)
    end

    it 'catches docker errors' do
      Docker::Image.unstub(:build_from_dir)
      Docker::Image.expects(:build_from_dir).raises(Docker::Error::DockerError.new("XYZ"))
      service.build_image(tmp_dir).must_equal nil
      build.docker_image_id.must_equal nil
    end

    it 'catches JSON errors' do
      push_output = [
        [{status: 'working okay'}.to_json],
        ['{"status":"this is incomplete JSON...']
      ]

      Docker::Image.unstub(:build_from_dir)
      Docker::Image.expects(:build_from_dir).
        multiple_yields(*push_output).
        returns(mock_docker_image)

      service.build_image(tmp_dir)
      service.output.to_s.must_include 'this is incomplete JSON'
    end
  end

  describe '#push_image' do
    let(:repo_digest) { 'sha256:5f1d7c7381b2e45ca73216d7b06004fdb0908ed7bb8786b62f2cdfa5035fde2c' }
    let(:push_output) do
      [
        [{status: "pushing image to repo..."}.to_json],
        [{status: "completed push."}.to_json],
        [{status: "Frobinating..."}.to_json],
        [{status: "Digest: #{repo_digest}"}.to_json],
        [{status: "Done"}.to_json]
      ]
    end

    before do
      mock_docker_image.stubs(:push)
      mock_docker_image.stubs(:tag)
      build.docker_image = mock_docker_image
    end

    it 'sets the values on the build' do
      mock_docker_image.expects(:push).multiple_yields(*push_output)
      build.label = "Version 123"
      service.push_image(nil)
      assert_equal('version-123', build.docker_ref)
      assert_equal("#{project.docker_repo}@#{repo_digest}", build.docker_repo_digest)
    end

    it 'saves docker output to the buffer' do
      mock_docker_image.expects(:push).multiple_yields(*push_output).once
      mock_docker_image.expects(:tag).once
      service.push_image(nil)
      assert_includes(service.output.to_s, 'Frobinating...')
      assert_equal('latest', build.docker_ref)
    end

    it 'uses the tag passed in' do
      mock_docker_image.expects(:tag)
      service.push_image('my-test')
      assert_equal('my-test', build.docker_ref)
    end

    describe 'pushing latest' do
      it 'adds the latest tag on top of the one specified when latest is true' do
        mock_docker_image.expects(:tag).with(has_entry(tag: 'my-test')).with(has_entry(tag: 'latest'))
        mock_docker_image.expects(:push).with(service.send(:registry_credentials), tag: 'latest', force: true)
        service.push_image('my-test', tag_as_latest: true)
      end

      it 'does not add the latest tag on top of the one specified when that tag is latest' do
        mock_docker_image.expects(:tag).never
        mock_docker_image.expects(:push).never
        service.push_image('latest', tag_as_latest: true)
      end

      it 'does not add the latest tag on top of the one specified when latest is false' do
        mock_docker_image.expects(:tag).never
        mock_docker_image.expects(:push).never
        service.push_image('my-test')
      end
    end
  end
end
