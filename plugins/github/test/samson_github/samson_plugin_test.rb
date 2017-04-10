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
      before { stage.update_github_pull_requests = true }

      it "sends github notifications if the stage has it enabled and deploy succeeded" do
        deploy.job.status = "succeeded"
        GithubNotification.any_instance.expects(:deliver)
        Samson::Hooks.fire(:after_deploy, deploy, nil)
      end

      it "does not send github notifications if the stage has it enabled and deploy failed" do
        deploy.stubs(:status).returns("failed")
        GithubNotification.any_instance.expects(:deliver).never
        Samson::Hooks.fire(:after_deploy, deploy, nil)
      end
    end

    describe "with deployments enabled" do
      before { stage.use_github_deployment_api = true }

      it "updates a github deployment status" do
        deployment = stub("Deployment")
        GithubDeployment.any_instance.expects(:create).returns(deployment)
        Samson::Hooks.fire(:before_deploy, deploy, nil)

        GithubDeployment.any_instance.expects(:update).with(deployment)
        Samson::Hooks.fire(:after_deploy, deploy, nil)
      end

      it "does not blow up when before hook already failed" do
        GithubDeployment.any_instance.expects(:update).never
        Samson::Hooks.fire(:after_deploy, deploy, nil)
      end
    end
  end

  describe :before_deploy do
    it "creates a github deployment" do
      stage.use_github_deployment_api = true
      GithubDeployment.any_instance.expects(:create)
      Samson::Hooks.fire(:before_deploy, deploy, nil)
    end
  end
end
