# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe GithubStatus do
  let(:repo) { "oompa/loompa" }
  let(:ref) { "wonka" }
  let(:project) { stub("project", repository_path: repo) }
  let(:release) { stub("release", project: project, commit: ref) }

  describe "#state" do
    let(:status) { GithubStatus.fetch(release) }

    it "returns `missing` if there's no response from Github" do
      GITHUB.stubs(:combined_status).returns(nil)
      status.state.must_equal "missing"
    end

    it "returns the Github state from the response" do
      GITHUB.stubs(:combined_status).returns({state: 'party', statuses: []})
      status.state.must_equal "party"
    end
  end

  describe "#statuses" do
    let(:status) { GithubStatus.fetch(release) }

    it "returns a single status per context" do
      # The most recent status is used.
      statuses = [
        {context: "A", created_at: 1, state: "pending"},
        {context: "B", created_at: 1, state: "success"},
        {context: "A", created_at: 2, state: "failure"},
      ]

      stub_api({state: "pending", statuses: statuses}, 200)

      status.statuses.count.must_equal 2

      status_a = status.statuses.first
      status_b = status.statuses.last

      assert status_a.failure?
      assert status_b.success?
    end

    it "includes the state of each status" do
      statuses = [
        {context: "A", created_at: 1, state: "pending"},
      ]

      stub_api({state: "pending", statuses: statuses}, 200)

      status.statuses.first.state.must_equal "pending"

      assert status.statuses.first.pending?
      assert !status.statuses.first.success?
      assert !status.statuses.first.failure?
    end

    it "includes the URL of each status" do
      statuses = [
        {context: "A", created_at: 1, state: "pending", target_url: "http://acme.com/123"},
      ]

      stub_api({state: "pending", statuses: statuses}, 200)

      status.statuses.first.url.must_equal "http://acme.com/123"
    end

    it "includes the description of each status" do
      statuses = [
        {context: "A", created_at: 1, state: "pending", description: "hello"},
      ]

      stub_api({state: "pending", statuses: statuses}, 200)

      status.statuses.first.description.must_equal "hello"
    end
  end

  it "has a query method for each state" do
    assert GithubStatus.new("success", []).success?
    assert GithubStatus.new("failure", []).failure?
    assert GithubStatus.new("pending", []).pending?
    assert GithubStatus.new("missing", []).missing?

    refute GithubStatus.new("wonka", []).success?
    refute GithubStatus.new("wonka", []).failure?
    refute GithubStatus.new("wonka", []).pending?
    refute GithubStatus.new("wonka", []).missing?
  end

  def stub_api(body, status = 200)
    stub_github_api "repos/#{repo}/commits/#{ref}/status", body, status
  end

  #def maxitest_timeout;false;end
end
