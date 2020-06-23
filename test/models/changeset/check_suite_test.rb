# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Changeset::CheckSuite do
  let(:data) do
    {
      "action" => "completed",
      "check_suite" => {
        "head_branch" => "master",
        "status" => "completed",
        "head_sha" => "1234",
        "conclusion" => "success"
      }
    }
  end
  let(:check_suite) { Changeset::CheckSuite.new('foo/bar', data) }

  describe "#branch" do
    it "finds" do
      check_suite.branch.must_equal 'master'
    end
  end

  describe ".valid_webhook?" do
    it "is true" do
      Changeset::CheckSuite.valid_webhook?(data).must_equal true
    end
  end

  describe ".changeset_from_webhook" do
    it "passes data on" do
      check_suite = Changeset::CheckSuite.changeset_from_webhook(projects(:test), data)
      check_suite.repo.must_equal "bar/foo"
    end
  end

  describe "#service_type" do
    it "is check_suite" do
      check_suite.service_type.must_equal "check_suite"
    end
  end

  describe "#sha" do
    it "returns a sha" do
      check_suite.sha.must_equal "1234"
    end
  end
end
