# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! uncovered: 1

describe GithubNotification do
  let(:pull_requests) { stub(number: 9) }
  let(:project) { stub(name: "Glitter", repository_path: "glitter/glitter", to_param: "3-glitter") }
  let(:stage) { stub(name: "staging", project: project, github_pull_request_comment: "") }
  let(:changeset) { stub_everything(commits: [], files: [], pull_requests: [pull_requests]) }
  let(:deploy) { stub(changeset: changeset, short_reference: "7e6c415", id: 18, stage: stage, to_param: "18") }
  let(:notification) { GithubNotification.new(deploy) }
  let(:endpoint) { "https://api.github.com/repos/glitter/glitter/issues/9/comments" }

  describe 'when there are pull requests' do
    it "adds a comment" do
      assert_request(:post, endpoint) do
        notification.deliver
      end
    end
  end

  describe '#body' do
    it 'uses the correct default message' do
      body = notification.send(:body)

      body.must_equal <<~TEXT.squish
        This PR was deployed to staging.
        Reference: <a href='http://www.test-url.com/projects/3-glitter/deploys/18' target='_blank'>7e6c415</a>
      TEXT
    end

    it 'uses the user supplied message' do
      stage.stubs(github_pull_request_comment: "Deployed to %{stage_name}, ref: %{reference}")

      body = notification.send(:body)

      body.must_equal <<~TEXT.squish
        Deployed to staging,
        ref: <a href='http://www.test-url.com/projects/3-glitter/deploys/18' target='_blank'>7e6c415</a>
      TEXT
    end
  end
end
