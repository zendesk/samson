require_relative '../test_helper'

describe GithubPullRequestDescription do
  let(:project) { stub(name: "Foo", github_repo: "foo", to_param: "42-foo") }
  let(:stage) { stub(name: "bar", project: project) }
  let(:github_description) { GithubPullRequestDescription.new(stage, deploy) }

  #let(:changeset) { stub_everything(commits: [], files: [], pull_requests: [pull_requests]) } let(:deploy) { stub(changeset: changeset, short_reference: "7e6c415", id: 18) }

  context 'when there are pull requests' do
    let(:pull_requests) { stub(number: 42)}

    describe "#update_deploy_status" do
      it "inserts samson deploy status" do
        owner = "lorem"
        repo = "foo"
        number = 42

        url = "https://api.github.com/repos/#{owner}/#{repo}/pulls/#{number}"

        pull_request = stub_request(:put, url)

        github_description.update_deploy_status

        assert_requested comment
      end
    end
  end
end
