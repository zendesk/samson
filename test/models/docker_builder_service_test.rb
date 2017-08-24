# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe DockerBuilderService do
  include GitRepoTestHelper

  let(:tmp_dir) { Dir.mktmpdir }
  let(:git_tag) { 'v123' }
  let(:project) { projects(:test) }
  let(:build) { project.builds.create!(git_ref: git_tag, git_sha: 'a' * 40, creator: users(:admin)) }
  let(:service) { DockerBuilderService.new(build) }
  let(:docker_image_id) { '2d2b0b3204b0166435c3d96d0b27d0ad2083e5e040192632c58eeb9491d6bfaa' }
  let(:docker_image_json) { { 'Id' => docker_image_id } }
  let(:mock_docker_image) { stub(json: docker_image_json) }
  let(:primary_repo) { project.docker_repo(DockerRegistry.first, 'Dockerfile') }

  with_registries ["docker-registry.example.com"]
  with_project_on_remote_repo

  before { execute_on_remote_repo "git tag #{git_tag}" }

  describe "#run" do
    def call(options = {})
      JobExecution.expects(:start_job).capture(start_jobs)
      service.run(options)
    end

    def execute_job
      job.instance_variable_get(:@execution_block).call(job, Dir.mktmpdir)
    end

    let(:start_jobs) { [] }
    let(:job) { start_jobs[0][0] }

    it "skips when already running to combat racey parallel deploys/builds" do
      JobExecution.expects(:start_job).never
      Rails.cache.write("build-service-#{build.id}", true)
      service.run
    end

    it "deletes previous build job" do
      build.docker_build_job = jobs(:succeeded_test)
      call
      assert_raises(ActiveRecord::RecordNotFound) { jobs(:succeeded_test).reload }
    end

    it "sends notifications when the job succeeds" do
      call
      Samson::Hooks.expects(:fire).with(:after_docker_build, anything)
      job.send(:finish)
    end

    it "uses name as tag when present" do
      build.name = 'Foo Bar baz'
      call
      job.send(:finish)
      build.docker_tag.must_equal 'foo-bar-baz'
    end

    it "tags as latest" do
      call
      job.send(:finish)
      build.docker_tag.must_equal 'latest'
    end

    it "builds, does not push and removes the image" do
      call

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
        call(push: false)

        service.expects(:build_image).returns(true) # simulate that build worked
        build.expects(:docker_image).never # image will not be removed
        build.expects(:docker_image).never # image will not be removed

        assert execute_job
      end
    end

    it "returns push_image result when it pushes" do
      with_env DOCKER_KEEP_BUILT_IMGS: "1" do
        call(push: true)

        # simulate that build worked
        service.expects(:build_image).returns(true)
        service.expects(:push_image).returns(123)

        execute_job.must_equal(123)
      end
    end

    it "fails when bla" do
      call(push: true)

      # simulate that build worked
      service.expects(:build_image).returns(false)
      service.expects(:push_image).never

      execute_job.must_equal(false)
    end

    it "runs via kubernetes when job is marked as kubernetes_job" do
      build.kubernetes_job = true
      with_env "DOCKER_KEEP_BUILT_IMGS" => "1" do
        call

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
      ["status: Random status", "BUILD DIGEST: #{primary_repo}@#{repo_digest}"].join("\n")
    end

    before { Kubernetes::BuildJobExecutor.expects(:new).returns k8s_job }

    it 'updates build metadata when the remote job completes' do
      k8s_job.expects(:execute).returns([true, build_log])

      service.send(:run_build_image_job, local_job)
      build.docker_repo_digest.must_equal "#{primary_repo}@#{repo_digest}"
    end

    it 'leaves the build docker metadata empty when the remote job fails' do
      k8s_job.expects(:execute).returns([false, build_log])

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
      Samson::Hooks.expects(:fire).with(:before_docker_repository_usage, build)
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
      TerminalExecutor.any_instance.expects(:execute).returns(true)
      OutputBuffer.any_instance.expects(:to_s).returns("Ignore me\nSuccessfully built bar\nSuccessfully built foobar")
      GitRepository.any_instance.expects(:commit_from_ref).returns("commitx")
      Docker::Image.stubs(:get).with("foobar").returns(mock_docker_image)
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

    it 'fails when docker build did not contain a image id' do
      OutputBuffer.any_instance.unstub(:to_s)
      OutputBuffer.any_instance.expects(:to_s).returns("some internal docker error")
      service.send(:build_image, tmp_dir).must_be_nil
      build.docker_image_id.must_be_nil
    end

    it 'catches docker errors' do
      TerminalExecutor.any_instance.unstub(:execute)
      TerminalExecutor.any_instance.expects(:execute).returns(false)
      OutputBuffer.any_instance.unstub(:to_s)
      OutputBuffer.any_instance.expects(:to_s).never
      service.send(:build_image, tmp_dir).must_be_nil
      build.docker_image_id.must_be_nil
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
    let(:output) { service.send(:output).to_s }

    before do
      build.docker_image = mock_docker_image
      build.docker_tag = tag
    end

    it 'stores generated repo digest' do
      mock_docker_image.expects(:tag).once
      stub_push primary_repo, tag, true

      assert service.send(:push_image), output
      build.docker_repo_digest.must_equal "#{primary_repo}@#{repo_digest}"
    end

    it 'uses a different repo for a uncommon dockerfile' do
      build.update_column(:dockerfile, "Dockerfile.secondary")
      mock_docker_image.expects(:tag).once
      stub_push "#{primary_repo}-secondary", tag, true

      assert service.send(:push_image), output
      build.docker_repo_digest.must_equal "#{primary_repo}-secondary@#{repo_digest}"
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
      let(:secondary_repo) { project.docker_repo(DockerRegistry.all[1], 'Dockerfile') }

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

  describe ".local_docker_login" do
    run_inside_of_temp_directory

    it "yields and returns" do
      (DockerBuilderService.send(:local_docker_login) { 1 }).must_equal 1
    end

    describe "login commands" do
      let(:called) do
        all = []
        DockerBuilderService.send(:local_docker_login) { |commands| all = commands }
        all
      end

      before do
        DockerRegistry.expects(:all).returns([DockerRegistry.new("http://fo+o:ba+r@ba+z.com")])
        DockerBuilderService.class_variable_set(:@@docker_major_version, nil)
      end

      it "uses email flag when docker is old" do
        DockerBuilderService.expects(:read_docker_version).returns("1.12.0")
        called[1].must_equal "docker login --username fo\\+o --password ba\\+r --email no@example.com ba\\+z.com"
      end

      it "uses email flag when docker check fails" do
        DockerBuilderService.expects(:read_docker_version).raises(Timeout::Error)
        called[1].must_equal "docker login --username fo\\+o --password ba\\+r --email no@example.com ba\\+z.com"
      end

      it "does not use email flag on newer docker versions" do
        DockerBuilderService.expects(:read_docker_version).returns("17.0.0")
        called[1].must_equal "docker login --username fo\\+o --password ba\\+r ba\\+z.com"
      end

      it "can do a real docker check" do
        called # checking that it does not blow up ... result varies depending on if docker is installed
      end
    end

    it "copies previous config files from ENV location" do
      File.write("config.json", "hello")
      with_env DOCKER_CONFIG: '.' do
        DockerBuilderService.send(:local_docker_login) do |commands|
          dir = commands.first[/DOCKER_CONFIG=(.*)/, 1]
          File.read("#{dir}/config.json").must_equal "hello"
        end
      end
    end

    it "copies previous config files from HOME location" do
      Dir.mkdir(".docker")
      File.write(".docker/config.json", "hello")
      with_env HOME: Dir.pwd do
        DockerBuilderService.send(:local_docker_login) do |commands|
          dir = commands.first[/DOCKER_CONFIG=(.*)/, 1]
          File.read("#{dir}/config.json").must_equal "hello"
        end
      end
    end
  end
end
