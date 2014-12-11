require_relative '../test_helper'

describe GithubPullRequestDescription do
  let(:project) { stub(name: "Foo", github_repo: "foo", to_param: "42-foo") }
  let(:stage) { stub(name: "bar", project: project) }
  let(:pull_request) { stub(number: 9) }
  let(:changeset) { stub_everything(commits: [], files: [], pull_requests: [pull_request]) }
  let(:deploy) { stub(changeset: changeset, short_reference: "7e6c415", id: 18) }

  let(:github_description) { GithubPullRequestDescription.new(stage, deploy) }

  context 'when there are pull requests' do
    describe "#update_deploy_status" do
      it "inserts samson deploy status" do
        owner = "lorem"
        repo = "foo"

        get_url = "repos/#{repo}/pulls/#{pull_request.number}"
        patch_url = "https://api.github.com/repos/#{owner}/#{repo}/pulls/#{pull_request.number}"

        #get_pr_request = stub_request(:get, get_url).to_return(
          #body: json_response.to_json,
          #headers: {'Content-Type' => 'application/json'}
        #)

        stub_github_api(get_url, { body: "Lorem ipsum dolor sit amet" })

        update_pr_request = stub_request(:patch, patch_url)

        github_description.update_deploy_status

        assert_requested comment
      end
    end
  end
end
