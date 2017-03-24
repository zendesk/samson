# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! uncovered: 2 # fork/wait call that we skip in unit tests

describe DockerBuilderService do
  include GitRepoTestHelper

  let(:tmp_dir) { Dir.mktmpdir }
  let(:git_tag) { 'v123' }
  let(:project) { projects(:test) }
  let(:build) { project.builds.create!(git_ref: git_tag, git_sha: 'a' * 40) }
  let(:service) { DockerBuilderService.new(build) }
  let(:docker_image_id) { '2d2b0b3204b0166435c3d96d0b27d0ad2083e5e040192632c58eeb9491d6bfaa' }
  let(:docker_image_json) { { 'Id' => docker_image_id } }
  let(:mock_docker_image) { stub(json: docker_image_json) }

  with_registries ["docker-registry.example.com"]
  with_project_on_remote_repo

  before { execute_on_remote_repo "git tag #{git_tag}" }

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

    it "uses label as tag when present" do
      build.label = 'Foo Bar baz'
      run!
      job.send(:finish)
      build.docker_tag.must_equal 'foo-bar-baz'
    end

    it "tags as latest" do
      run!
      job.send(:finish)
      build.docker_tag.must_equal 'latest'
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
      with_env DOCKER_KEEP_BUILT_IMGS: "1" do
        run!(push: false)

        service.expects(:build_image).returns(true) # simulate that build worked
        build.expects(:docker_image).never # image will not be removed
        build.expects(:docker_image).never # image will not be removed

        assert execute_job
      end
    end

    it "returns push_image result when it pushes" do
      with_env DOCKER_KEEP_BUILT_IMGS: "1" do
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
    let(:build_log) do
      ["status: Random status", "BUILD DIGEST: #{project.docker_repo(DockerRegistry.first)}@#{repo_digest}"].join("\n")
    end

    before { Kubernetes::BuildJobExecutor.expects(:new).returns k8s_job }

    it 'updates build metadata when the remote job completes' do
      k8s_job.expects(:execute!).returns([true, build_log])

      service.send(:run_build_image_job, local_job)
      assert_equal("#{project.docker_repo(DockerRegistry.first)}@#{repo_digest}", build.docker_repo_digest)
    end

    it 'leaves the build docker metadata empty when the remote job fails' do
      k8s_job.expects(:execute!).returns([false, build_log])

      service.send(:run_build_image_job, local_job)
      assert_nil build.docker_repo_digest
    end
  end

  describe '#before_docker_build' do
    let(:before_docker_build_path) { File.join(tmp_dir, 'samson/before_docker_build') }
    let(:output) { StringIO.new }
    let(:execution) { JobExecution.new('master', Job.new(project: project), output: output) { raise } }

    before { service.instance_variable_set(:@execution, execution) }

    it 'fires the before_docker_build hook' do
      Samson::Hooks.expects(:fire).with(:before_docker_repository_usage, build.project)
      Samson::Hooks.expects(:fire).with(:before_docker_build, tmp_dir, build, anything)
      service.send(:before_docker_build, tmp_dir)
    end

    describe "with build_command" do
      let(:command) { Command.create!(command: "echo foo\r\necho bar") }

      before do
        project.update_column(:build_command_id, command.id)
        freeze_time
      end

      it "executes it" do
        service.send(:before_docker_build, tmp_dir)
        output.string.must_include \
          "» echo foo\r\nfoo\r\n» echo bar\r\nbar\r\n"
        output.string.must_include "export CACHE_DIR="
      end

      it "can resolve secrets" do
        create_secret "global/#{project.permalink}/global/foo"
        command.update_column(:command, "echo secret://foo")
        service.send(:before_docker_build, tmp_dir)
        output.string.must_include "» echo secret://foo\r\nMY-SECRET\r\n"
      end

      it "fails when command fails" do
        command.update_column(:command, 'exit 1')
        e = assert_raises Samson::Hooks::UserError do
          service.send(:before_docker_build, tmp_dir)
        end
        e.message.must_equal "Error running build command"
        output.string.must_include "» exit 1\r\n"
      end
    end
  end

  describe "#build_image" do
    before do
      Docker::Util.stubs(:create_relative_dir_tar).returns(nil)
      Docker::Image.stubs(:build_from_tar).returns(mock_docker_image)
    end

    it 'calls #before_docker_build' do
      service.expects(:before_docker_build).with(tmp_dir)
      service.send(:build_image, tmp_dir)
    end

    it 'writes the REVISION file' do
      service.send(:build_image, tmp_dir)
      revision_filepath = File.join(tmp_dir, 'REVISION')
      assert File.exist?(revision_filepath)
      assert_equal(build.git_sha, File.read(revision_filepath))
    end

    it 'updates the Build object' do
      service.send(:build_image, tmp_dir)
      assert_equal(docker_image_id, build.docker_image_id)
    end

    it 'catches docker errors' do
      error_message = "A bad thing happened..."
      Docker::Image.unstub(:build_from_tar)
      Docker::Image.expects(:build_from_tar).raises(Docker::Error::DockerError.new(error_message))
      service.send(:build_image, tmp_dir).must_be_nil
      build.docker_image_id.must_be_nil
      service.send(:output).to_s.must_include error_message
    end

    it 'catches UnexpectedResponseErrors' do
      error_message = "Really long output..."
      Docker::Image.unstub(:build_from_tar)
      Docker::Image.expects(:build_from_tar).raises(Docker::Error::UnexpectedResponseError.new(error_message))
      service.send(:build_image, tmp_dir).must_be_nil
      build.docker_image_id.must_be_nil
      service.send(:output).to_s.wont_include error_message
    end

    it 'catches JSON errors' do
      push_output = [
        [{status: 'working okay'}.to_json],
        ['{"status":"this is incomplete JSON...']
      ]

      Docker::Image.unstub(:build_from_tar)
      Docker::Image.expects(:build_from_tar).
        multiple_yields(*push_output).
        returns(mock_docker_image)

      service.send(:build_image, tmp_dir)
      service.send(:output).to_s.must_include 'this is incomplete JSON'
    end
  end

  describe "#push_image" do
    def stub_push(repo, tag, result, force: false)
      mock_docker_image.
        expects(:push).
        with(anything, repo_tag: "#{repo}:#{tag}", force: force).
        multiple_yields(*push_output).
        returns(result)
    end

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
    let(:tag) { 'my-test' }
    let(:primary_repo) { project.docker_repo(DockerRegistry.first) }
    let(:output) { service.send(:output).to_s }

    before do
      build.docker_image = mock_docker_image
      build.docker_tag = tag
    end

    it 'stores generated repo digest' do
      mock_docker_image.expects(:tag).once
      stub_push primary_repo, tag, true

      assert service.send(:push_image), output
      build.docker_repo_digest.must_equal "#{project.docker_repo(DockerRegistry.first)}@#{repo_digest}"
    end

    it 'saves docker output to the buffer' do
      mock_docker_image.expects(:tag).once
      stub_push primary_repo, tag, true

      assert service.send(:push_image), output
      output.must_include 'Frobinating...'
    end

    it 'rescues docker error' do
      service.expects(:push_image_to_registries).raises(Docker::Error::DockerError)
      refute service.send(:push_image)
      output.to_s.must_include "Docker push failed: Docker::Error::DockerError"
    end

    describe 'with credentials' do
      with_registries ['usr:pas@reg']

      it 'pushes with credentials' do
        with_env(DOCKER_REGISTRY_EMAIL: 'eml') do
          mock_docker_image.expects(:tag)
          mock_docker_image.expects(:push).with(
            {username: 'usr', password: 'pas', email: 'eml', serveraddress: DockerRegistry.first.host},
            repo_tag: "#{primary_repo}:#{tag}", force: false
          ).multiple_yields(*push_output).returns(true)

          assert service.send(:push_image), output
        end
      end
    end

    it 'fails when digest cannot be found' do
      assert push_output.reject! { |e| e.first =~ /Digest/ }
      mock_docker_image.expects(:tag)
      stub_push primary_repo, tag, true

      refute service.send(:push_image)
      output.to_s.must_include "Docker push failed: Unable to get repo digest"
    end

    describe "with secondary registry" do
      let(:secondary_repo) { project.docker_repo(DockerRegistry.all[1]) }

      with_registries ["docker-registry.example.com", 'extra.registry']

      it "pushes to primary and secondary registry" do
        mock_docker_image.expects(:tag).twice
        stub_push primary_repo, tag, true
        stub_push secondary_repo, tag, true
        assert service.send(:push_image), output
        build.docker_tag.must_equal tag
      end

      it "stops and fails when pushing to primary registry fails" do
        mock_docker_image.expects(:tag)
        stub_push primary_repo, tag, false
        refute service.send(:push_image)
      end

      it "fails when pushing to secondary registry fails" do
        mock_docker_image.expects(:tag).twice
        stub_push primary_repo, tag, true
        stub_push secondary_repo, tag, false
        refute service.send(:push_image)
      end
    end

    describe 'pushing latest' do
      it 'adds the latest tag on top of the one specified' do
        mock_docker_image.expects(:tag).with(has_entry(tag: tag))
        mock_docker_image.expects(:tag).with(has_entry(tag: 'latest'))

        stub_push(primary_repo, tag, true)
        stub_push(primary_repo, 'latest', true, force: true)

        assert service.send(:push_image, tag_as_latest: true), output
      end

      it 'does not add the latest tag on top of the one specified when that tag is latest' do
        build.docker_tag = 'latest'
        mock_docker_image.expects(:tag).with(has_entry(tag: 'latest'))
        stub_push(primary_repo, 'latest', true, force: true)

        assert service.send(:push_image, tag_as_latest: true), output
      end
    end
  end
end
