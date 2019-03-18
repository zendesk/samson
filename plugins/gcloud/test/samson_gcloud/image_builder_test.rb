# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SamsonGcloud::ImageBuilder do
  let(:build) { builds(:docker_build) }

  describe ".build_image" do
    def expect_succeeded_build
      executor.expects(:execute).with { output.write "foo digest: sha-123:abc" }.returns(true)
    end

    def build_image(tag_as_latest: false, cache_from: nil)
      SamsonGcloud::ImageBuilder.build_image(dir, build, executor, tag_as_latest: tag_as_latest, cache_from: cache_from)
    end

    let(:dir) { "some-dir" }
    let(:output) { OutputBuffer.new }
    let(:executor) { TerminalExecutor.new(output, verbose: true, project: build.project) }
    let(:repo) { 'gcr.io/p-123/samson/foo' }

    with_env GCLOUD_PROJECT: 'p-123', GCLOUD_ACCOUNT: 'acc'

    around { |test| Dir.mktmpdir { |dir| Dir.chdir(dir) { test.call } } }

    before { Dir.mkdir 'some-dir' }

    it "builds using a custom cloudbuild.yml" do
      build_image
      File.read("some-dir/cloudbuild.yml").must_equal <<~YML
        steps:
        - name: 'gcr.io/cloud-builders/docker'
          args: [ 'build', '--tag', '#{repo}:#{build.git_sha}', '--file', 'Dockerfile', '.' ]
        images:
        - '#{repo}'
        tags:
        - '#{build.git_sha}'
      YML
    end

    it "can use cache" do
      Samson::CommandExecutor.expects(:execute).returns([true, "sha256:abc\n"])
      old = 'gcr.io/something-old@sha256:abc'
      build_image(cache_from: old)
      File.read("some-dir/cloudbuild.yml").must_equal <<~YML
        steps:
        - name: 'gcr.io/cloud-builders/docker'
          args: ['pull', '#{old}']
        - name: 'gcr.io/cloud-builders/docker'
          args: [ 'build', '--tag', '#{repo}:#{build.git_sha}', '--file', 'Dockerfile', '--cache-from', '#{old}', '.' ]
        images:
        - '#{repo}'
        tags:
        - '#{build.git_sha}'
      YML
    end

    it "does not use cache when image is not available" do
      Samson::CommandExecutor.expects(:execute).returns([true, "\n"])
      build_image(cache_from: 'gcr.io/something-old')
      File.read("some-dir/cloudbuild.yml").must_equal <<~YML
        steps:
        - name: 'gcr.io/cloud-builders/docker'
          args: [ 'build', '--tag', '#{repo}:#{build.git_sha}', '--file', 'Dockerfile', '.' ]
        images:
        - '#{repo}'
        tags:
        - '#{build.git_sha}'
      YML
      output.messages.must_include "not found in gcr"
    end

    it "tags latest when requested" do
      build_image(tag_as_latest: true)
      File.read("some-dir/cloudbuild.yml").must_equal <<~YML
        steps:
        - name: 'gcr.io/cloud-builders/docker'
          args: [ 'build', '--tag', '#{repo}:#{build.git_sha}', '--tag', '#{repo}:latest', '--file', 'Dockerfile', '.' ]
        images:
        - '#{repo}'
        tags:
        - '#{build.git_sha}'
        - 'latest'
      YML
    end

    it "returns the docker repo digest" do
      expect_succeeded_build
      build_image.must_equal "#{repo}@sha-123:abc"
      build.external_url.must_be_nil
    end

    it "returns nil on failure" do
      executor.expects(:execute).returns(false)
      build_image.must_be_nil
    end

    it "fails when cloudbuild.yml already exists since that is not supported" do
      File.write("some-dir/cloudbuild.yml", "foo")
      e = assert_raises(Samson::Hooks::UserError) { build_image }
      e.message.must_equal "cloudbuild.yml already exists, use external builds"
    end

    it "returns nil when digest was not found" do
      executor.expects(:execute).returns(true)
      build_image.must_be_nil
    end

    it "stores external url" do
      url = "https://console.cloud.google.com/gcr/builds/someid?project=fooo"
      executor.expects(:execute).with do
        output.puts "[23:45:46] Logs are permanently available at [#{url}]."
        output.puts "[23:45:46] foo digest: sha-123:abc"
      end.returns(true)
      build_image.must_equal "#{repo}@sha-123:abc"
      build.external_url.must_equal url
    end

    it "uses executor timeout" do
      executor.expects(:execute).with do |*commands|
        commands.join.must_include("--timeout 5")
      end.returns(true)
      build_image
    end

    it "builds different Dockerfiles" do
      build.dockerfile = 'Dockerfile.changed'
      expect_succeeded_build
      build_image.must_equal "#{repo}-changed@sha-123:abc"
      build.external_url.must_be_nil
    end

    it "ignores files that are in dockerignore since we only build" do
      File.write("some-dir/.dockerignore", "foo")
      File.write("some-dir/.gitignore", "foo")
      build_image
      File.read("some-dir/.gcloudignore").must_equal "#!include:.gitignore\n#!include:.dockerignore"
    end

    it "ignores Dockerfile if Dockerfile is in dockerignore" do
      File.write("some-dir/.dockerignore", "foo\nDockerfile\nbar")
      build_image
      File.read("some-dir/.dockerignore").must_equal "foo\n\nbar"
    end

    it "does not include missing files and ignores .git by default" do
      build_image
      File.read("some-dir/.gcloudignore").must_equal ".git"
    end

    it "keeps ignores files if they are configured" do
      File.write("some-dir/.gcloudignore", "X")
      build_image
      File.read("some-dir/.gcloudignore").must_equal "X"
    end
  end
end
