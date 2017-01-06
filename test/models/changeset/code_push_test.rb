# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Changeset::CodePush do
  let(:data) do
    {
      "ref" => "refs/heads/master",
      "after" => "abc-sha"
    }
  end
  let(:push) { Changeset::CodePush.new('foo/bar', data) }

  describe "#branch" do
    it "finds" do
      push.branch.must_equal 'master'
    end

    it "does not find for a tagging" do
      data["ref"] = "refs/tags/v3"
      data["base_ref"] = "refs/heads/master"
      push.branch.must_equal nil
    end
  end

  describe "#sha" do
    it "finds" do
      push.sha.must_equal "abc-sha"
    end
  end

  describe "#service_type" do
    it "is code" do
      push.service_type.must_equal "code"
    end
  end

  describe ".valid_webhook?" do
    it "is true" do
      Changeset::CodePush.valid_webhook?(1).must_equal true
    end
  end

  describe ".changeset_from_webhook" do
    it "passes data on" do
      push = Changeset::CodePush.changeset_from_webhook(projects(:test), data)
      push.repo.must_equal "bar/foo"
    end
  end
end
