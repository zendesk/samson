# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SamsonGcloud::TagResolver do
  with_env GCLOUD_ACCOUNT: 'acc', GCLOUD_PROJECT: 'proj'

  describe ".resolve_docker_image_tag" do
    let(:image) { +"gcr.io/foo/bar" }
    let(:digest) { "sha256:#{"a" * 64}" }

    it "resolves latest" do
      Samson::CommandExecutor.expects(:execute).
        returns(OpenStruct.new(status: true, output: {image_summary: {digest: digest}}.to_json))
      SamsonGcloud::TagResolver.resolve_docker_image_tag(image).must_equal "#{image}@#{digest}"
    end

    it "resolves custom tag" do
      Samson::CommandExecutor.expects(:execute).
        returns(OpenStruct.new(status: true, output: {image_summary: {digest: digest}}.to_json))
      SamsonGcloud::TagResolver.resolve_docker_image_tag("#{image}:foo").must_equal "#{image}@#{digest}"
    end

    it "does not resolve non-gcr" do
      SamsonGcloud::TagResolver.resolve_docker_image_tag("foo.bar/abc").must_be_nil
    end

    it "does not re-resolve digests" do
      SamsonGcloud::TagResolver.resolve_docker_image_tag("#{image}@#{digest}").must_be_nil
    end

    it "raises on gcloud error" do
      Samson::CommandExecutor.expects(:execute).
        returns(OpenStruct.new(status: false, output: ""))
      assert_raises RuntimeError do
        SamsonGcloud::TagResolver.resolve_docker_image_tag(image)
      end
    end
  end
end
