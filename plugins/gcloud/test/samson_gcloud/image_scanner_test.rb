# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SamsonGcloud::ImageScanner do
  with_env GCLOUD_ACCOUNT: 'acc', GCLOUD_PROJECT: 'proj'

  let(:build) { builds(:docker_build) }

  describe ".scan" do
    def assert_done(status = "FINISHED_SUCCESS")
      assert_request(
        :get, /DISCOVERY/,
        to_return: {body: {occurrences: [{discovered: {analysisStatus: status}}]}.to_json}
      )
    end

    assert_requests

    before do
      Samson::CommandExecutor.expects(:execute).returns([true, "foo"])
      build.updated_at = 1.hour.ago
    end

    it "returns success" do
      assert_done
      assert_request(:get, /PACKAGE_VULNERABILITY/, to_return: {body: "[]"})
      SamsonGcloud::ImageScanner.scan(build).must_equal SamsonGcloud::ImageScanner::SUCCESS
    end

    it "returns found" do
      assert_done
      assert_request(:get, /PACKAGE_VULNERABILITY/, to_return: {body: "[111]"})
      SamsonGcloud::ImageScanner.scan(build).must_equal SamsonGcloud::ImageScanner::FOUND
    end

    it "returns error when not found" do
      assert_done
      assert_request(:get, /PACKAGE_VULNERABILITY/, to_return: {status: 400, body: "[]"})
      SamsonGcloud::ImageScanner.scan(build).must_equal SamsonGcloud::ImageScanner::ERROR
    end

    it "returns error when it blows up" do
      assert_done
      assert_request(:get, /PACKAGE_VULNERABILITY/, to_timeout: [])
      SamsonGcloud::ImageScanner.scan(build).must_equal SamsonGcloud::ImageScanner::ERROR
    end

    it "returns waiting when build was not yet scanned" do
      assert_done "PENDING"
      SamsonGcloud::ImageScanner.scan(build).must_equal SamsonGcloud::ImageScanner::WAITING
    end

    it "returns waiting when build is in progress" do
      assert_done "SCANNING"
      SamsonGcloud::ImageScanner.scan(build).must_equal SamsonGcloud::ImageScanner::WAITING
    end

    it "returns err if we are unable to determine the status" do
      assert_request(:get, /DISCOVERY/, to_return: {body: "{}"})
      SamsonGcloud::ImageScanner.scan(build).must_equal SamsonGcloud::ImageScanner::ERROR
    end

    it "retries request if error code >= 500" do
      assert_request(:get, /DISCOVERY/, to_return: {status: 500}, times: 3)
      SamsonGcloud::ImageScanner.scan(build).must_equal SamsonGcloud::ImageScanner::ERROR
    end

    it "supports digests with https prefix (idk if that really happens)" do
      build.update_column(:docker_repo_digest, "https://#{build.docker_repo_digest}")
      assert_done "SCANNING"
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
      SamsonGcloud::ImageScanner.status(0).must_equal "Waiting for Vulnerability scan"
      SamsonGcloud::ImageScanner.status(1).must_equal "No vulnerabilities found"
      SamsonGcloud::ImageScanner.status(2).must_equal "Vulnerabilities found"
      SamsonGcloud::ImageScanner.status(3).must_equal "Error retrieving vulnerabilities"
    end

    it "raises on invalid status" do
      assert_raises { SamsonGcloud::ImageScanner.status(5) }
    end
  end

  describe ".token" do
    it "does not cache errors" do
      Samson::CommandExecutor.expects(:execute).times(2).returns([false, '1'], [true, '2'])
      assert_raises { SamsonGcloud::ImageScanner.send(:token) }
      SamsonGcloud::ImageScanner.send(:token).must_equal '2'
    end
  end
end
