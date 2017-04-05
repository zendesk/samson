# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SamsonDatadog do
  let(:deploy) { deploys(:succeeded_test) }
  let(:stage) { deploy.stage }

  describe :stage_permitted_params do
    it "lists extra keys" do
      Samson::Hooks.fire(:stage_permitted_params).must_include(
        [:update_github_pull_requests, :use_github_deployment_api]
      )
    end
  end

  describe :after_deploy do
    describe "with github notifications enabled" do
      before { stage.stubs(:update_github_pull_requests?).returns(true) }

      it "sends github notifications if the stage has it enabled and deploy succeeded" do
        deploy.stubs(:status).returns("succeeded")
        GithubNotification.any_instance.expects(:deliver)
        Samson::Hooks.fire(:after_deploy, deploy, nil)
      end

      it "does not send github notifications if the stage has it enabled and deploy failed" do
        deploy.stubs(:status).returns("failed")
        GithubNotification.any_instance.expects(:deliver).never
        Samson::Hooks.fire(:after_deploy, deploy, nil)
      end
    end

    it "updates a github deployment status" do
      stage.stubs(:use_github_deployment_api?).returns(true)

      deployment = stub("Deployment")
      GithubDeployment.any_instance.expects(:create_github_deployment).returns(deployment)
      Samson::Hooks.fire(:before_deploy, deploy, nil)

      GithubDeployment.any_instance.expects(:update_github_deployment_status).with(deployment)
      Samson::Hooks.fire(:after_deploy, deploy, nil)
    end
  end

  describe :before_deploy do
    it "creates a github deployment" do
      stage.stubs(:use_github_deployment_api?).returns(true)
      GithubDeployment.any_instance.expects(:create_github_deployment)
      Samson::Hooks.fire(:before_deploy, deploy, nil)
    end
  end
end
