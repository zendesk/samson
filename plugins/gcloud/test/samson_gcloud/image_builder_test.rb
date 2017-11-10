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

    before do
      SamsonGcloud.stubs(container_in_beta: [])
      SamsonGcloud::ImageBuilder.stubs(gcloud_project_id: 'p-123')
    end

    it "returns the docker repo digest" do
      TerminalExecutor.any_instance.expects(:execute).with { output.write "foo digest: sha-123:abc" }.returns(true)
      build_image.must_equal "gcr.io/p-123/samson/bar-foo@sha-123:abc"
    end

    it "returns nil on failure" do
      TerminalExecutor.any_instance.expects(:execute).returns(false)
      build_image.must_be_nil
    end

    it "returns nil when digest was not found" do
      TerminalExecutor.any_instance.expects(:execute).returns(true)
      build_image.must_be_nil
    end

    it "blows up when trying to use an unsupported Dockerfile" do
      dockerfile << 'foo'
      e = assert_raises(RuntimeError) { build_image }
      e.message.must_include "Dockerfile"
    end
  end

  describe ".gcloud_project_id" do
    before { SamsonGcloud::ImageBuilder.class_variable_set(:@@gcloud_project_id, nil) }

    def gcloud_project_id
      SamsonGcloud::ImageBuilder.send :gcloud_project_id
    end

    it "returns project id and caches it" do
      Samson::CommandExecutor.expects(:execute).returns([true, {core: {project: "abc"}}.to_json])
      gcloud_project_id.must_equal "abc"
      gcloud_project_id.must_equal "abc"
    end

    it "ignores non-json that old versions output" do
      Samson::CommandExecutor.expects(:execute).returns(
        [true, "Your active configuration is: [default]:\n\n#{{core: {project: "abc"}}.to_json}"]
      )
      gcloud_project_id.must_equal "abc"
    end

    it "blows up on failure" do
      Samson::CommandExecutor.expects(:execute).returns([false, "XXXX"])
      assert_raises(JSON::ParserError) { gcloud_project_id }
    end
  end
end
