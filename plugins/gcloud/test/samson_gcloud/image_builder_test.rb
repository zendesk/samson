# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SamsonGcloud::ImageBuilder do
  let(:build) { builds(:docker_build) }

  describe ".build_image" do
    def build_image
      SamsonGcloud::ImageBuilder.build_image(build, dir, output, dockerfile: dockerfile)
    end

    let(:dir) { "foo" }
    let(:output) { OutputBuffer.new }
    let(:dockerfile) { "Dockerfile".dup }

    with_env GCLOUD_PROJECT: 'p-123', GCLOUD_ACCOUNT: 'acc'

    before { SamsonGcloud.stubs(container_in_beta: []) }

    it "returns the docker repo digest" do
      TerminalExecutor.any_instance.expects(:execute).with { output.write "foo digest: sha-123:abc" }.returns(true)
      build_image.must_equal "gcr.io/p-123/samson/bar-foo@sha-123:abc"
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
      build_image.must_equal "gcr.io/p-123/samson/bar-foo@sha-123:abc"
      build.external_url.must_equal url
    end

    it "blows up when trying to use an unsupported Dockerfile" do
      dockerfile << 'foo'
      e = assert_raises(RuntimeError) { build_image }
      e.message.must_include "Dockerfile"
    end
  end
end
