require 'test_helper'

describe Changeset::PullRequest do
  describe "#users" do
    let(:data) { stub("data", user: user, merged_by: merged_by) }
    let(:pr) { Changeset::PullRequest.new("xxx", data) }
    let(:user) { stub(login: "foo") }
    let(:merged_by) { stub(login: "bar") }
    let(:data) { stub("data", user: user, merged_by: merged_by) }

    it "returns the users associated with the pull request" do
      pr.users.map(&:login).must_equal ["foo", "bar"]
    end

    it "excludes duplicate users" do
      merged_by.stubs(:login).returns("foo")
      pr.users.map(&:login).must_equal ["foo"]
    end
  end
end
