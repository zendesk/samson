# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SamsonGcloud::ImageScanner do
  with_env GCLOUD_ACCOUNT: 'acc', GCLOUD_PROJECT: 'proj'

  let(:build) { builds(:docker_build) }

  describe ".scan" do
    before do
      Samson::CommandExecutor.expects(:execute).returns([true, "foo"])
      build.updated_at = 1.hour.ago
    end

    it "returns success" do
      assert_request(:get, /containeranalysis/, to_return: {body: "[]"}) do
        SamsonGcloud::ImageScanner.scan(build).must_equal SamsonGcloud::ImageScanner::SUCCESS
      end
    end

    it "returns found" do
      assert_request(:get, /containeranalysis/, to_return: {body: "[111]"}) do
        SamsonGcloud::ImageScanner.scan(build).must_equal SamsonGcloud::ImageScanner::FOUND
      end
    end

    it "returns error when not found" do
      assert_request(:get, /containeranalysis/, to_return: {status: 400, body: "[]"}) do
        SamsonGcloud::ImageScanner.scan(build).must_equal SamsonGcloud::ImageScanner::ERROR
      end
    end

    it "returns error when it blows up" do
      assert_request(:get, /containeranalysis/, to_timeout: []) do
        SamsonGcloud::ImageScanner.scan(build).must_equal SamsonGcloud::ImageScanner::ERROR
      end
    end

    it "returns waiting when build was not yet scanned" do
      build.updated_at = Time.now
      Samson::CommandExecutor.unstub(:execute)
      Samson::CommandExecutor.expects(:execute).never
      SamsonGcloud::ImageScanner.scan(build).must_equal SamsonGcloud::ImageScanner::WAITING
    end
  end

  describe ".result_url" do
    it "builds" do
      SamsonGcloud::ImageScanner.result_url(build).must_include "https://"
    end

    it "is nil when build is not finished" do
      build.docker_repo_digest = nil
      SamsonGcloud::ImageScanner.result_url(build).must_be_nil
    end
  end

  describe ".status" do
    it "produces valid stati" do
      [0, 1, 2, 3].each do |status_id|
        assert SamsonGcloud::ImageScanner.status(status_id)
      end
    end

    it "raises on invalid status" do
      assert_raises { SamsonGcloud::ImageScanner.status(5) }
    end
  end
end
