# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe GithubDeployment do
  include StubGithubAPI

  let(:user) { users(:deployer) }
  let(:project) { projects(:test) }
  let(:stage) { stages(:test_staging) }
  let(:deploy) { deploys(:succeeded_test) }
  let(:github_deployment) { GithubDeployment.new(deploy) }

  describe "#create_github_deployment" do
    let(:endpoint) { "https://api.github.com/repos/bar/foo/deployments" }

    it "uses GitHub api" do
      deploy = stub_request(:post, endpoint)
      github_deployment.create_github_deployment

      assert_requested deploy
    end
  end

  describe "#update_github_deployment_status" do
    let(:deployment_endpoint) { "repos/bar/foo/deployments/42" }
    let(:deployment_status_endpoint) { "https://api.github.com/deployment/status" }
    let(:deployment) { stub(url: deployment_endpoint) }

    it "uses GitHub api" do
      stub_github_api(deployment_endpoint, rels: { statuses: { href: deployment_status_endpoint } })

      deploy = stub_request(:post, deployment_status_endpoint)
      github_deployment.update_github_deployment_status(deployment)

      assert_requested deploy
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

    it "fails for impossible" do
      deploy.job.status = "pending"
      assert_raises(ArgumentError) { github_deployment.send(:state) }
    end
  end
end
