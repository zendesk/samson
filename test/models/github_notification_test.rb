require_relative '../test_helper'

describe GithubNotification do
  let(:project) { stub(name: "Glitter", github_repo: "glitter/glitter", to_param: "3-glitter") }
  let(:stage) { stub(name: "staging", project: project) }
  let(:changeset) { stub_everything(commits: [], files: [], pull_requests: [pull_requests]) }
  let(:deploy) { stub(changeset: changeset, short_reference: "7e6c415", id: 18, stage: stage) }
  let(:notification) { GithubNotification.new(deploy) }
  let(:endpoint) { "https://api.github.com/repos/glitter/glitter/issues/9/comments" }

  describe 'when there are pull requests' do
    let(:pull_requests) { stub(number: 9)}

    it "adds a comment" do
      comment = stub_request(:post, endpoint)
      notification.deliver

      assert_requested comment
    end
  end
end
