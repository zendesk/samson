# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SamsonGcloud::ImageBuilder do
  let(:build) { builds(:docker_build) }

  describe ".build_image" do
    def build_image(tag_as_latest: false)
      SamsonGcloud::ImageBuilder.build_image(build, dir, output, tag_as_latest: tag_as_latest)
    end

    let(:dir) { "some-dir" }
    let(:output) { OutputBuffer.new }
    let(:repo) { 'gcr.io/p-123/samson/foo' }

    with_env GCLOUD_PROJECT: 'p-123', GCLOUD_ACCOUNT: 'acc'

    around { |test| Dir.mktmpdir { |dir| Dir.chdir(dir) { test.call } } }

    before do
      Dir.mkdir 'some-dir'
      SamsonGcloud.stubs(container_in_beta: [])
    end

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
      TerminalExecutor.any_instance.expects(:execute).with { output.write "foo digest: sha-123:abc" }.returns(true)
      build_image.must_equal "#{repo}@sha-123:abc"
      build.external_url.must_be_nil
    end

    it "returns nil on failure" do
      TerminalExecutor.any_instance.expects(:execute).returns(false)
      build_image.must_be_nil
    end

    it "returns nil when digest was not found" do
      TerminalExecutor.any_instance.expects(:execute).returns(true)
      build_image.must_be_nil
    end

    it "stores external url" do
      url = "https://console.cloud.google.com/gcr/builds/someid?project=fooo"
      TerminalExecutor.any_instance.expects(:execute).with do
        output.puts "[23:45:46] Logs are permanently available at [#{url}]."
        output.puts "[23:45:46] foo digest: sha-123:abc"
      end.returns(true)
      build_image.must_equal "#{repo}@sha-123:abc"
      build.external_url.must_equal url
    end

    it "builds different Dockerfiles" do
      build.dockerfile = 'Dockerfile.changed'
      TerminalExecutor.any_instance.expects(:execute).with { output.write "foo digest: sha-123:abc" }.returns(true)
      build_image.must_equal "#{repo}-changed@sha-123:abc"
      build.external_url.must_be_nil
    end
  end
end
