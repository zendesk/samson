# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe DockerBuilderService do
  let(:tmp_dir) { Dir.mktmpdir }
  let(:git_tag) { 'v123' }
  let(:project) { projects(:test) }
  let(:build) { project.builds.create!(git_ref: git_tag, git_sha: 'a' * 40, creator: users(:admin)) }
  let(:service) { DockerBuilderService.new(build) }
  let(:docker_image_id) { '2d2b0b3204b0166435c3d96d0b27d0ad2083e5e040192632c58eeb9491d6bfaa' }
  let(:docker_image_json) { { 'Id' => docker_image_id } }
  let(:mock_docker_image) { stub(json: docker_image_json) }
  let(:primary_repo) { project.docker_repo(DockerRegistry.first, 'Dockerfile') }
  let(:digest) { "foo.com@sha256:#{"a" * 64}" }

  with_registries ["docker-registry.example.com"]

  before do
    GitRepository.any_instance.expects(:clone!).with { raise }.never # nice backtraces
    Build.any_instance.stubs(:validate_git_reference)
  end

  describe "#run" do
    def call(options = {})
      JobQueue.expects(:perform_later).capture(perform_laters)
      service.run(options)
    end

    def execute_job
      job.instance_variable_get(:@execution_block).call(job, Dir.mktmpdir)
    end

    let(:perform_laters) { [] }
    let(:job) { perform_laters[0][0] }

    it "skips when already running to combat racey parallel deploys/builds" do
      JobQueue.expects(:perform_later).never
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

    it "fails when image fails to build" do
      call(push: true)

      # simulate that build worked
      service.expects(:build_image).returns(false)
      service.expects(:push_image).never

      execute_job.must_equal(false)
    end

    it "can store docker_repo_digest from GCB" do
      build.project.build_with_gcb = true
      service.expects(:build_image).with { build.docker_repo_digest = digest }.returns(true)
      call
      assert execute_job
      build.reload.docker_repo_digest.must_equal digest
    end

    it "updates docker_repo_digest when rebuildng an image" do
      with_env DOCKER_KEEP_BUILT_IMGS: "1" do
        build.update_column :docker_repo_digest, "old-#{digest}"
        call(push: true)

        # simulate that build worked
        service.expects(:build_image).returns(true)
        service.expects(:push_image).with { build.docker_repo_digest = digest }.returns(123)

        assert execute_job
        build.reload.docker_repo_digest.must_equal digest
      end
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
    let(:executor) { TerminalExecutor.new(OutputBuffer.new) }

    before do
      service.instance_variable_set(:@execution, stub("Ex", executor: executor))
      executor.expects(:execute).with do
        executor.output.puts "Ignore me\nSuccessfully built bar\nSuccessfully built foobar"
        true
      end.returns(true)
      Docker::Image.stubs(:get).with("foobar").returns(mock_docker_image)
    end

    it 'calls #before_docker_build' do
      service.expects(:before_docker_build).with(tmp_dir)
      service.send(:build_image, tmp_dir, tag_as_latest: false)
    end

    it 'writes the REVISION file' do
      service.send(:build_image, tmp_dir, tag_as_latest: false)
      revision_filepath = File.join(tmp_dir, 'REVISION')
      assert File.exist?(revision_filepath)
      File.read(revision_filepath).must_equal build.git_sha
    end

    it 'updates the Build object' do
      service.send(:build_image, tmp_dir, tag_as_latest: false)
      build.docker_image_id.must_equal docker_image_id
    end

    it 'fails when docker build did not contain a image id' do
      OutputBuffer.any_instance.unstub(:to_s)
      OutputBuffer.any_instance.expects(:to_s).returns("some internal docker error")
      service.send(:build_image, tmp_dir, tag_as_latest: false).must_be_nil
      build.docker_image_id.must_be_nil
    end

    it 'catches docker errors' do
      executor.unstub(:execute)
      executor.expects(:execute).returns(false)
      OutputBuffer.any_instance.unstub(:to_s)
      OutputBuffer.any_instance.expects(:to_s).never
      service.send(:build_image, tmp_dir, tag_as_latest: false).must_be_nil
      build.docker_image_id.must_be_nil
    end

    describe "caching from the previous build" do
      before do
        executor.unstub(:execute)
        build.update_column(:docker_repo_digest, digest)
      end

      it 'uses last build as cache' do
        executor.expects(:execute).
          with do |*args|
          args.join(" ").must_include " --cache-from #{build.docker_repo_digest}"
          args.join(" ").must_include "docker pull #{build.docker_repo_digest}"
          true
        end.returns(true)
        service.send(:build_image, tmp_dir, tag_as_latest: false)
      end

      it 'does not use cache when the last build failed' do
        Build.update_all docker_repo_digest: nil
        executor.expects(:execute).
          with { |*args| args.join(" ").wont_include "--cache-from"; true }.
          returns(true)
        service.send(:build_image, tmp_dir, tag_as_latest: false)
      end

      it 'does not use cache when the last build was for a different dockerfile' do
        Build.update_all dockerfile: 'noop'
        executor.expects(:execute).
          with { |*args| args.join(" ").wont_include "--cache-from"; true }.
          returns(true)
        service.send(:build_image, tmp_dir, tag_as_latest: false)
      end
    end

    describe "build_with_gcb" do
      before do
        executor.unstub(:execute)
        executor.stubs(:execute).with do |*commands|
          executor.output.puts "digest: sha-123:abc" if commands.to_s.include?("gcloud container builds submit")
          true
        end.returns(true)
      end

      it "stores docker_repo_digest directly" do
        with_env GCLOUD_PROJECT: 'p-123', GCLOUD_ACCOUNT: 'acc' do
          build.project.build_with_gcb = true
          assert service.send(:build_image, tmp_dir, tag_as_latest: false)
          refute build.docker_image_id
          build.docker_repo_digest.sub(/samson\/[^@]+/, "X").must_equal "gcr.io/p-123/X@sha-123:abc"
        end
      end
    end
  end

  describe "#push_image" do
    def stub_push(repo, tag, result)
      executor.expects(:execute).with do |*commands|
        service.send(:output).puts push_output.join("\n")
        commands.to_s.include?("export DOCKER_CONFIG") &&
          commands.to_s.include?("docker tag fake-id #{repo}:#{tag}") &&
          commands.to_s.include?("docker push #{repo}:#{tag}")
      end.returns(result)
    end

    let(:repo_digest) { 'sha256:5f1d7c7381b2e45ca73216d7b06004fdb0908ed7bb8786b62f2cdfa5035fde2c' }
    let(:push_output) do
      [
        "pushing image to repo...",
        "Ignore this Digest: #{repo_digest.tr("5", "F")}",
        "completed push.",
        "Frobinating...",
        +"Digest: #{repo_digest}"
      ]
    end
    let(:tag) { 'my-test' }
    let(:output) { service.send(:output).to_s }
    let(:executor) { TerminalExecutor.new(service.output) }

    before do
      build.docker_image = mock_docker_image
      build.docker_tag = tag
      execution = stub("Execution", executor: executor)
      service.instance_variable_set(:@execution, execution)
      mock_docker_image.stubs(:id).returns("fake-id")
    end

    it 'stores generated repo digest' do
      stub_push primary_repo, tag, true

      assert service.send(:push_image), output
      build.docker_repo_digest.must_equal "#{primary_repo}@#{repo_digest}"
    end

    it 'uses a different repo for a uncommon dockerfile' do
      build.update_column(:dockerfile, "Dockerfile.secondary")
      stub_push "#{primary_repo}-secondary", tag, true

      assert service.send(:push_image), output
      build.docker_repo_digest.must_equal "#{primary_repo}-secondary@#{repo_digest}"
    end

    it 'saves docker output to the buffer' do
      stub_push primary_repo, tag, true

      assert service.send(:push_image), output
      output.must_include 'Frobinating...'
    end

    it 'rescues docker error' do
      service.expects(:push_image_to_registries).raises(Docker::Error::DockerError)
      refute service.send(:push_image)
      output.to_s.must_include "Docker push failed: Docker::Error::DockerError"
    end

    it 'fails when digest cannot be found' do
      assert push_output.reject! { |e| e =~ /Digest/ }
      stub_push primary_repo, tag, true

      refute service.send(:push_image)
      output.to_s.must_include "Docker push failed: Unable to get repo digest"
    end

    describe "with secondary registry" do
      let(:secondary_repo) { project.docker_repo(DockerRegistry.all[1], 'Dockerfile') }

      with_registries ["docker-registry.example.com", 'extra.registry']

      it "pushes to primary and secondary registry" do
        stub_push secondary_repo, tag, true
        stub_push primary_repo, tag, true
        assert service.send(:push_image), output
        build.docker_tag.must_equal tag
      end

      it "stops and fails when pushing to primary registry fails" do
        stub_push primary_repo, tag, false
        refute service.send(:push_image)
      end

      it "fails when pushing to secondary registry fails" do
        stub_push primary_repo, tag, true
        stub_push secondary_repo, tag, false
        refute service.send(:push_image)
      end
    end

    describe 'pushing latest' do
      it 'adds the latest tag on top of the one specified' do
        stub_push(primary_repo, tag, true)
        stub_push(primary_repo, 'latest', true)

        assert service.send(:push_image, tag_as_latest: true), output
      end

      it 'does not add the latest tag on top of the one specified when that tag is latest' do
        build.docker_tag = 'latest'
        stub_push(primary_repo, 'latest', true)

        assert service.send(:push_image, tag_as_latest: true), output
      end
    end
  end
end
