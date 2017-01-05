# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe BuildsHelper do
  describe "#short_sha" do
    it "shortens the sha" do
      short_sha("sha256:0123abcsdfghjk").must_equal "0123abc"
    end

    it "returns nothing when there is no value" do
      short_sha(nil).must_equal nil
    end
  end

  describe "#git_ref_and_sha_for" do
    it "returns nothing when there are no sha and no ref" do
      git_ref_and_sha_for(Build.new).must_equal nil
    end

    it "returns only the sha when there is no ref" do
      git_ref_and_sha_for(Build.new(git_sha: 'abcdefghijkl')).must_equal "abcdefg"
    end

    it "returns sha and ref and builds a link" do
      build = Build.new(git_ref: "foo", git_sha: 'abcdefghijkl')
      build.expects(:commit_url).returns "ba.com"
      result = git_ref_and_sha_for(build, make_link: true)
      result.must_equal "foo (<a href=\"ba.com\">abcdefg</a>)"
      assert result.html_safe?
    end
  end
end
