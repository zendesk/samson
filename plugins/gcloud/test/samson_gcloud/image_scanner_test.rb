# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SamsonGcloud::ImageScanner do
  with_env GCLOUD_ACCOUNT: 'acc', GCLOUD_PROJECT: 'proj'

  let(:image) { 'foo.com/proj/image@sha256:abcdef' }

  describe ".scan" do
    def assert_done(status = "FINISHED_SUCCESS")
      assert_request(
        :get, /DISCOVERY/,
        to_return: {body: {occurrences: [{discovered: {discovered: {analysisStatus: status}}}]}.to_json}
      )
    end

    def scan
      SamsonGcloud::ImageScanner.scan(image)
    end

    assert_requests

    before do
      Samson::CommandExecutor.expects(:execute).returns([true, "foo"])
    end

    it "returns success" do
      assert_done
      assert_request(:get, /PACKAGE_VULNERABILITY/, to_return: {body: "[]"})
      scan.must_equal SamsonGcloud::ImageScanner::SUCCESS
    end

    it "returns found" do
      assert_done
      assert_request(:get, /PACKAGE_VULNERABILITY/, to_return: {body: "[111]"})
      scan.must_equal SamsonGcloud::ImageScanner::FOUND
    end

    it "returns error when not found" do
      assert_done
      assert_request(:get, /PACKAGE_VULNERABILITY/, to_return: {status: 400, body: "[]"})
      scan.must_equal SamsonGcloud::ImageScanner::ERROR
    end

    it "returns error when it blows up" do
      assert_done
      assert_request(:get, /PACKAGE_VULNERABILITY/, to_timeout: [])
      scan.must_equal SamsonGcloud::ImageScanner::ERROR
    end

    it "returns waiting when image was not yet scanned" do
      assert_done "PENDING"
      scan.must_equal SamsonGcloud::ImageScanner::WAITING
    end

    it "returns waiting when image scan is in progress" do
      assert_done "SCANNING"
      scan.must_equal SamsonGcloud::ImageScanner::WAITING
    end

    it "returns err if we are unable to determine the status" do
      assert_request(:get, /DISCOVERY/, to_return: {body: "{}"})
      scan.must_equal SamsonGcloud::ImageScanner::ERROR
    end

    it "retries request if error code >= 500" do
      assert_request(:get, /DISCOVERY/, to_return: {status: 500}, times: 3)
      scan.must_equal SamsonGcloud::ImageScanner::ERROR
    end

    it "supports digests with https prefix (idk if that really happens)" do
      assert_done "SCANNING"
      SamsonGcloud::ImageScanner.scan("https://#{image}").must_equal SamsonGcloud::ImageScanner::WAITING
    end

    it "shows unsupported when image is not scannable because it is from another project" do
      Samson::CommandExecutor.unstub(:execute)
      SamsonGcloud::ImageScanner.scan('foo_image').must_equal SamsonGcloud::ImageScanner::UNSUPPORTED
    end

    it "shows unsupported when image is not scannable because it is not a sha" do
      Samson::CommandExecutor.unstub(:execute)
      SamsonGcloud::ImageScanner.scan(image.split('@').first).must_equal SamsonGcloud::ImageScanner::UNSUPPORTED
    end

    it "caches final results" do
      Samson::CommandExecutor.unstub(:execute)
      SamsonGcloud::ImageScanner.expects(:uncached_scan).times(1).returns(SamsonGcloud::ImageScanner::SUCCESS)
      2.times { SamsonGcloud::ImageScanner.scan('foo').must_equal SamsonGcloud::ImageScanner::SUCCESS }
    end

    it "does not cache pending results" do
      Samson::CommandExecutor.unstub(:execute)
      SamsonGcloud::ImageScanner.expects(:uncached_scan).times(2).returns(SamsonGcloud::ImageScanner::WAITING)
      2.times { SamsonGcloud::ImageScanner.scan('foo').must_equal SamsonGcloud::ImageScanner::WAITING }
    end
  end

  describe ".result_url" do
    it "builds" do
      SamsonGcloud::ImageScanner.result_url(image).must_include "https://"
    end

    it "is nil when build is not finished" do
      SamsonGcloud::ImageScanner.result_url(nil).must_be_nil
    end

    it "is nil when image is not scannable" do
      SamsonGcloud::ImageScanner.result_url('foo_image').must_be_nil
    end

    it "can scan images that include gcloud projects twice" do
      SamsonGcloud::ImageScanner.result_url("#{image}/proj/bar").must_include ":abcdef/proj/bar/details/"
    end
  end

  describe ".status" do
    it "produces valid statuses" do
      SamsonGcloud::ImageScanner.status(0).must_equal "Waiting for Vulnerability scan"
      SamsonGcloud::ImageScanner.status(1).must_equal "No vulnerabilities found"
      SamsonGcloud::ImageScanner.status(2).must_equal "Vulnerabilities found"
      SamsonGcloud::ImageScanner.status(3).must_equal "Error retrieving vulnerabilities"
      SamsonGcloud::ImageScanner.status(4).
        must_equal "Only full gcr repos in proj with shas are supported for scanning"
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
