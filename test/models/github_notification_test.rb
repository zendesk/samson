require 'test_helper'

describe GithubNotification do
  let(:stage) { stub(name: "staging") }
  let(:project) { stub(name: "Glitter", github_repo: "glitter") }
  let(:changeset) { stub_everything(commits: [], files: [], pull_requests: [pull_requests]) }
  let(:deploy) { stub(changeset: changeset, project: project, short_reference: "7e6c415") }
  let(:notification) { GithubNotification.new(stage, deploy) }
  let(:endpoint) { "https://api.github.com/repos/glitter/issues/9/comments" }

  describe 'when there are pull requests' do

    let(:pull_requests) { stub(number: 9)}

    it "adds a comment" do
      comment = stub_request(:post, endpoint).
                  with(:body => "{\"body\":\"This PR was deployed to staging. Reference: 7e6c415\"}",
                     :headers => {'Accept'=>'application/vnd.github.beta+json', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'User-Agent'=>'Octokit Ruby Gem 2.7.0'}).
                  to_return(:status => 201, :body => "", :headers => {})
      notification.deliver

      assert_requested comment
    end
  end

  describe 'when there are no pull requests' do
    let(:pull_requests) {}

    it "doesn't add a comment" do
      notification.deliver
      assert_not_requested :post, endpoint
    end
  end
end
