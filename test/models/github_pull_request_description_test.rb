require_relative '../test_helper'

describe GithubPullRequestDescription, :model do
  include StubGithubAPI

  let(:changeset) {  }

  describe "#update_deploy_status" do
    it "inserts samson deploy status" do
      project = projects(:test)
      stage = stages(:test_staging)
      deploy = deploys(:succeeded_test)
      pull_request = stub(number: 9)
      changeset = stub_everything(commits: [], files: [], pull_requests: [pull_request])
      deploy.stubs(changeset: changeset)

      subject = GithubPullRequestDescription.new(stage, deploy)

      get_url = "repos/bar/foo/pulls/#{pull_request.number}"
      stub_github_api(get_url, { body: "Lorem ipsum dolor sit amet" })

      patch_url = "repos/bar/foo/pulls/#{pull_request.number}"
      update_pr_request = stub_request(:patch, patch_url)

      stub_github_api("repos/bar/foo/compare/staging...staging")

      subject.update_deploy_status

      assert_requested update_pr_request
    end
  end
end
