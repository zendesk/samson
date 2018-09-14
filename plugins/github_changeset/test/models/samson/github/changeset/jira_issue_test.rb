# frozen_string_literal: true
require_relative '../../../../test_helper'

SingleCov.covered!

describe Samson::Github::Changeset::JiraIssue do
  let(:issue) { Samson::Github::Changeset::JiraIssue.new("http://foo.com/bar/baz") }

  describe "#reference" do
    it "returns the last part of the url" do
      issue.reference.must_equal "baz"
    end
  end

  describe "#==" do
    it "is the same when the urls are the same" do
      other = Samson::Github::Changeset::JiraIssue.new("http://foo.com/bar/baz")
      (issue == other).must_equal true
    end

    it "is not the same when the urls are not the same" do
      other = Samson::Github::Changeset::JiraIssue.new("http://foos.com/bars/bazs")
      (issue == other).must_equal false
    end
  end
end
