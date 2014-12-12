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

      stub_github_api("repos/bar/foo/compare/staging...staging")

      get_url = "repos/bar/foo/pulls/#{pull_request.number}"
      stub_github_api(get_url, { body: "Lorem ipsum dolor sit amet" })

      patch_url = "https://api.github.com/repos/bar/foo/pulls/#{pull_request.number}"
      stub_request(:patch, patch_url)

      subject.update_deploy_status

      expected_body = %Q({"body":"Lorem ipsum dolor sit amet\n      ##### Samson is deploying staging\n\n      \n\n- Staging :heavy_check_mark:\n"})

      assert_requested(:path, patch_url) do |req|
        true
      end
    end
  end
end
