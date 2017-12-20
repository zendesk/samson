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

  describe "#build_status_badge" do
    include StatusHelper

    let(:build) { builds(:docker_build) }

    it "renders succeeded" do
      build_status_badge(build).must_include ">Succeeded<"
    end

    it "renders a regular build" do
      build.docker_build_job = jobs(:succeeded_test)
      build.docker_build_job.status = "running"
      build_status_badge(build).must_include ">Running<"
    end

    it "renders not built when digest is missing" do
      build.docker_repo_digest = nil
      build_status_badge(build).must_equal "not built"
    end

    it "renders external status" do
      build.docker_repo_digest = nil
      build.external_status = "cancelling"
      build_status_badge(build).must_include ">Cancelling<"
    end

    it "does not render unfinished builds that claim to be succeeded" do
      build.docker_repo_digest = nil
      build.external_status = "succeeded"
      build_status_badge(build).must_equal "not built"
    end
  end
end
