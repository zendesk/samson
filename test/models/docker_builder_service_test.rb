# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe DockerBuilderService do
  let(:tmp_dir) { Dir.mktmpdir }
  let(:project) { projects(:test) }
  let(:build) { project.builds.create!(git_ref: 'v123', git_sha: 'a' * 40, creator: users(:admin)) }
  let(:service) { DockerBuilderService.new(build) }
  let(:image_id) { '2d2b0b3204b0166435c3d96d0b27d0ad2083e5e040192632c58eeb9491d6bfaa' }
  let(:docker_image) { Docker::Image.new(Docker.connection, "id" => image_id) }
  let(:primary_repo) { project.docker_repo(DockerRegistry.first, 'Dockerfile') }
  let(:digest) { "foo.com@sha256:#{"a" * 64}" }

  with_registries ["docker-registry.example.com"]

  before do
    GitRepository.any_instance.expects(:clone!).with { raise }.never # nice backtraces
    Build.any_instance.stubs(:validate_git_reference)
  end

  describe "#run" do
    def call
      JobQueue.expects(:perform_later).capture(perform_laters)
      service.run
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

    it "fails when image fails to build" do
      call

      ImageBuilder.expects(:build_image).returns(nil)

      refute execute_job
    end

    it "can store docker_repo_digest from GCB" do
      build.project.build_with_gcb = true
      SamsonGcloud::ImageBuilder.expects(:build_image).returns(digest)
      call
      assert execute_job
      build.reload.docker_repo_digest.must_equal digest
    end

    it "updates docker_repo_digest when rebuildng an image" do
      with_env DOCKER_KEEP_BUILT_IMGS: "1" do
        build.update_column :docker_repo_digest, "old-#{digest}"
        call

        ImageBuilder.expects(:build_image).returns(digest)

        assert execute_job
        build.reload.docker_repo_digest.must_equal digest
      end
    end
  end

  describe "#build_image" do
    def call
      service.send(:build_image, tmp_dir, tag_as_latest: false)
    end

    let(:executor) { TerminalExecutor.new(OutputBuffer.new, verbose: true, project: project) } # verbose

    before do
      ImageBuilder.expects(:build_image).returns(digest)
      service.instance_variable_set(:@execution, stub("JobExecution", executor: executor, output: OutputBuffer.new))
    end

    it 'return the repo digest' do
      call.must_equal digest
    end

    it 'calls #before_docker_build' do
      service.expects(:before_docker_build).with(tmp_dir)
      call
    end

    it 'writes the REVISION file' do
      call
      revision_filepath = File.join(tmp_dir, 'REVISION')
      assert File.exist?(revision_filepath)
      File.read(revision_filepath).must_equal build.git_sha
    end

    describe "caching from the previous build" do
      before do
        build.update_column(:docker_repo_digest, digest)
        ImageBuilder.unstub(:build_image)
      end

      it 'uses last build as cache' do
        ImageBuilder.expects(:build_image).with { |*args| args.last[:cache_from].must_equal build.docker_repo_digest }
        call
      end

      it 'does not use cache when the last build failed' do
        Build.update_all docker_repo_digest: nil
        ImageBuilder.expects(:build_image).with { |*args| args.last[:cache_from].must_be_nil }
        call
      end

      it 'does not use cache when the last build was for a different dockerfile' do
        Build.update_all dockerfile: 'noop'
        ImageBuilder.expects(:build_image).with { |*args| args.last[:cache_from].must_be_nil }
        call
      end
    end

    it "can build with GCB" do
      build.project.build_with_gcb = true
      ImageBuilder.unstub(:build_image)
      SamsonGcloud::ImageBuilder.expects(:build_image).returns(digest)
      call.must_equal digest
    end
  end

  describe '#before_docker_build' do
    let(:before_docker_build_path) { File.join(tmp_dir, 'samson/before_docker_build') }
    let(:output) { execution.output.messages.gsub("[04:05:06] ", "") }
    let(:execution) { JobExecution.new('master', Job.new(project: project)) { raise } }

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
        output.must_include \
          "» echo foo\r\nfoo\r\n» echo bar\r\nbar\r\n"
        output.must_include "export CACHE_DIR="
      end

      it "can resolve secrets" do
        create_secret "global/#{project.permalink}/global/foo"
        command.update_column(:command, "echo secret://foo")
        service.send(:before_docker_build, tmp_dir)
        output.must_include "» echo secret://foo\r\nMY-SECRET\r\n"
      end

      it "fails when command fails" do
        command.update_column(:command, 'exit 1')
        e = assert_raises Samson::Hooks::UserError do
          service.send(:before_docker_build, tmp_dir)
        end
        e.message.must_equal "Error running build command"
        output.must_include "» exit 1\r\n"
      end
    end
  end
end
