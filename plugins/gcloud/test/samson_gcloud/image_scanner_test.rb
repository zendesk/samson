# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SamsonGcloud::ImageScanner do
  with_env GCLOUD_ACCOUNT: 'acc', GCLOUD_PROJECT: 'proj'

  let(:build) { builds(:docker_build) }

  describe ".scan" do
    def assert_done(done: true)
      assert_request(
        :get, /occurrences/,
        to_return: {body: {occurrences: [{discovered: {operation: {done: done}}}]}.to_json}
      )
    end

    assert_requests

    before do
      Samson::CommandExecutor.expects(:execute).returns([true, "foo"])
      build.updated_at = 1.hour.ago
    end

    it "returns success" do
      assert_done
      assert_request(:get, /vulnzsummary/, to_return: { body: "[]" })
      SamsonGcloud::ImageScanner.scan(build).must_equal SamsonGcloud::ImageScanner::SUCCESS
    end

    it "returns found" do
      assert_done
      assert_request(:get, /vulnzsummary/, to_return: { body: "[111]" })
      SamsonGcloud::ImageScanner.scan(build).must_equal SamsonGcloud::ImageScanner::FOUND
    end

    it "returns error when not found" do
      assert_done
      assert_request(:get, /vulnzsummary/, to_return: { status: 400, body: "[]" })
      SamsonGcloud::ImageScanner.scan(build).must_equal SamsonGcloud::ImageScanner::ERROR
    end

    it "returns error when it blows up" do
      assert_done
      assert_request(:get, /vulnzsummary/, to_timeout: [])
      SamsonGcloud::ImageScanner.scan(build).must_equal SamsonGcloud::ImageScanner::ERROR
    end

    it "returns waiting when build was not yet scanned or in progress" do
      assert_done(done: false)
      SamsonGcloud::ImageScanner.scan(build).must_equal SamsonGcloud::ImageScanner::WAITING
    end

    it "returns waiting if we are unable to determine the status" do
      assert_request(:get, /occurrences/, to_return: { body: "{}" })
      SamsonGcloud::ImageScanner.scan(build).must_equal SamsonGcloud::ImageScanner::WAITING
    end

    it "retries request if error code >= 500" do
      assert_request(:get, /occurrences/, to_return: { status: 500 }, times: 3)
      SamsonGcloud::ImageScanner.scan(build).must_equal SamsonGcloud::ImageScanner::ERROR
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
      SamsonGcloud::ImageScanner.status(0).must_equal "Waiting for Vulnerability scan"
      SamsonGcloud::ImageScanner.status(1).must_equal "No vulnerabilities found"
      SamsonGcloud::ImageScanner.status(2).must_equal "Vulnerabilities found"
      SamsonGcloud::ImageScanner.status(3).must_equal "Error retrieving vulnerabilities"
    end

    it "raises on invalid status" do
      assert_raises { SamsonGcloud::ImageScanner.status(5) }
    end
  end
end
