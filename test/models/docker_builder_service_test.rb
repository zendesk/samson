# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe DockerBuilderService do
  include GitRepoTestHelper

  let(:tmp_dir) { Dir.mktmpdir }
  let(:project_repo_url) { repo_temp_dir }
  let(:git_tag) { 'v123' }
  let(:project) { projects(:test).tap { |p| p.repository_url = project_repo_url } }

  let(:build) { project.builds.create!(git_ref: git_tag, git_sha: 'a' * 40) }
  let(:service) { DockerBuilderService.new(build) }

  let(:docker_image_id) { '2d2b0b3204b0166435c3d96d0b27d0ad2083e5e040192632c58eeb9491d6bfaa' }
  let(:docker_image_json) do
    {
      'Id' => docker_image_id
    }
  end
  let(:mock_docker_image) { stub(json: docker_image_json) }

  before { create_repo_with_tags(git_tag) }

  describe "#run!" do
    def run!(options = {})
      JobExecution.expects(:start_job).capture(start_jobs)
      service.run!(options)
    end

    def execute_job
      job.instance_variable_get(:@execution_block).call(job, Dir.mktmpdir)
    end

    let(:start_jobs) { [] }
    let(:job) { start_jobs[0][0] }

    it "deletes previous build job" do
      build.docker_build_job = jobs(:succeeded_test)
      run!
      assert_raises(ActiveRecord::RecordNotFound) { jobs(:succeeded_test).reload }
    end

    it "sends notifications when the job succeeds" do
      run!
      Samson::Hooks.expects(:fire).with(:after_docker_build, anything)
      job.send(:finish)
    end

    it "builds, does not push and removes the image" do
      run!

      # simulate that build worked
      service.expects(:build_image).returns(true)
      service.expects(:push_image).never

      # simulate falling removal ... should not change return value
      build.stubs(docker_image: stub)
      build.docker_image.expects(:remove).with(force: true).returns(false)

      assert execute_job
    end

    it "does not remove when DOCKER_KEEP_BUILT_IMGS is set" do
      with_env "DOCKER_KEEP_BUILT_IMGS" => "1" do
        run!(push: false)

        service.expects(:build_image).returns(true) # simulate that build worked
        build.expects(:docker_image).never # image will not be removed
        build.expects(:docker_image).never # image will not be removed

        assert execute_job
      end
    end

    it "returns push_image result when it pushes" do
      with_env "DOCKER_KEEP_BUILT_IMGS" => "1" do
        run!(push: true)

        # simulate that build worked
        service.expects(:build_image).returns(true)
        service.expects(:push_image).returns(123)

        execute_job.must_equal(123)
      end
    end

    it "runs via kubernetes when job is marked as kubernetes_job" do
      build.kubernetes_job = true
      with_env "DOCKER_KEEP_BUILT_IMGS" => "1" do
        run!

        # simulate that build worked
        service.expects(:build_image).never
        service.expects(:run_build_image_job).returns(123)

        execute_job.must_equal(123)
      end
    end
  end

  describe "#run_build_image_job" do
    let(:local_job) { stub }
    let(:k8s_job) { stub }
    let(:repo_digest) { 'sha256:5f1d7c7381b2e45ca73216d7b06004fdb0908ed7bb8786b62f2cdfa5035fde2c' }
    let(:build_log) { ["status: Random status", "BUILD DIGEST: #{project.docker_repo}@#{repo_digest}"].join("\n") }

    before do
      Kubernetes::BuildJobExecutor.expects(:new).returns k8s_job
    end

    it 'updates build metadata when the remote job completes' do
      k8s_job.expects(:execute!).returns([true, build_log])
      build.label = "Version 123"

      service.run_build_image_job(local_job, nil)
      assert_equal('version-123', build.docker_ref)
      assert_equal("#{project.docker_repo}@#{repo_digest}", build.docker_repo_digest)
    end

    it 'leaves the build docker metadata empty when the remote job fails' do
      k8s_job.expects(:execute!).returns([false, build_log])

      service.run_build_image_job(local_job, nil)
      assert_nil build.docker_repo_digest
    end
  end

  describe "#build_image" do
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

  describe "#push_image" do
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

    it 'rescues docker error' do
      service.expects(:docker_image_ref).raises(Docker::Error::DockerError)
      service.push_image('my-test').must_equal nil
      service.output.to_s.must_equal "Docker push failed: Docker::Error::DockerError\n"
    end

    it 'pushes with credentials when DOCKER_REGISTRY is set' do
      with_env(
        'DOCKER_REGISTRY' => 'reg',
        'DOCKER_REGISTRY_USER' => 'usr',
        'DOCKER_REGISTRY_PASS' => 'pas',
        'DOCKER_REGISTRY_EMAIL' => 'eml'
      ) do
        mock_docker_image.unstub(:push)
        mock_docker_image.expects(:push).with(
          username: 'usr', password: 'pas', email: 'eml', serveraddress: 'reg'
        ).multiple_yields(*push_output)
        build.label = "Version 123"
        service.push_image(nil)
        assert_equal('version-123', build.docker_ref)
      end
    end

    describe 'pushing latest' do
      it 'adds the latest tag on top of the one specified when latest is true' do
        mock_docker_image.expects(:tag).with(has_entry(tag: 'my-test')).with(has_entry(tag: 'latest'))
        mock_docker_image.expects(:push).
          with(service.send(:registry_credentials), tag: 'latest', force: true).
          multiple_yields(*push_output)
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
