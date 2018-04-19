# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe GithubDeployment do
  let(:user) { users(:deployer) }
  let(:project) { projects(:test) }
  let(:stage) { stages(:test_staging) }
  let(:deploy) { deploys(:succeeded_test) }
  let(:github_deployment) { GithubDeployment.new(deploy) }

  describe "#create" do
    let(:endpoint) { "https://api.github.com/repos/bar/foo/deployments" }

    it "creates a deployment" do
      body = {
        payload: {
          deployer: {id: deploy.user.id, name: deploy.user.name, email: deploy.user.email},
          buddy: nil
        },
        environment: "Staging",
        description: "Super Admin deployed staging to Staging",
        production_environment: false,
        auto_merge: false,
        required_contexts: [],
        ref: "abcabcaaabcabcaaabcabcaaabcabcaaabcabca1"
      }
      assert_request(:post, endpoint, with: {body: body.to_json}) do
        github_deployment.create
      end
    end
  end

  describe "#update" do
    let(:deployment_endpoint) { "repos/bar/foo/deployments/42" }
    let(:deployment_status_endpoint) { "https://api.github.com/deployment/status" }
    let(:deployment) { stub(url: deployment_endpoint) }

    it "uses GitHub api" do
      stub_github_api(deployment_endpoint, rels: {statuses: {href: deployment_status_endpoint}})

      assert_request(:post, deployment_status_endpoint) do
        github_deployment.update(deployment)
      end
    end
  end

  describe "#state" do
    it "renders failed" do
      deploy.job.status = "failed"
      github_deployment.send(:state).must_equal "failure"
    end

    it "renders error" do
      deploy.job.status = "errored"
      github_deployment.send(:state).must_equal "error"
    end

    it "renders cancelled" do
      deploy.job.status = "cancelled"
      github_deployment.send(:state).must_equal "failure"
    end

    it "fails for impossible" do
      deploy.job.status = "pending"
      assert_raises(ArgumentError) { github_deployment.send(:state) }
    end
  end
end
