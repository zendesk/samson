# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SamsonDatadog do
  let(:deploy) { deploys(:succeeded_test) }
  let(:stage) { deploy.stage }

  describe :stage_permitted_params do
    it "lists extra keys" do
      Samson::Hooks.fire(:stage_permitted_params).must_include(
        [:update_github_pull_requests, :use_github_deployment_api, :github_pull_request_comment]
      )
    end
  end

  describe :after_deploy do
    only_callbacks_for_plugin :after_deploy

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
    only_callbacks_for_plugin :before_deploy

    it "creates a github deployment" do
      stage.use_github_deployment_api = true
      GithubDeployment.any_instance.expects(:create)
      Samson::Hooks.fire(:before_deploy, deploy, nil)
    end

    it "does not create a github deployment when not enabled" do
      stage.use_github_deployment_api = false
      Samson::Hooks.fire(:before_deploy, deploy, nil)
    end
  end

  describe :repo_provider_status do
    def fire
      Samson::Hooks.fire(:repo_provider_status)
    end

    let(:status_url) { "#{SamsonGithub::STATUS_URL}/api/v2/status.json" }

    only_callbacks_for_plugin :repo_provider_status

    it "reports good response" do
      assert_request(:get, status_url, to_return: {body: {status: {indicator: 'none'}}.to_json}) do
        fire.must_equal [nil]
      end
    end

    it "reports bad response" do
      assert_request(:get, status_url, to_return: {body: {status: {indicator: 'critical'}}.to_json}) do
        fire.to_s.must_include "GitHub may be having problems"
      end
    end

    it "reports invalid response" do
      assert_request(:get, status_url, to_return: {status: 400}) do
        fire.to_s.must_include "GitHub may be having problems"
      end
    end

    it "reports errors" do
      assert_request(:get, status_url, to_timeout: []) do
        fire.to_s.must_include "GitHub may be having problems"
      end
    end
  end

  describe :repo_commit_from_ref do
    let(:project) { Project.new(repository_url: 'ssh://git@github.com:foo/bar.git') }

    def fire(reference)
      Samson::Hooks.fire(:repo_commit_from_ref, project, reference)
    end

    only_callbacks_for_plugin :repo_commit_from_ref

    it "skips non-github" do
      project.stubs(:github?).returns(false)
      fire("master").must_equal [nil]
    end

    it "resolves a refernece" do
      stub_github_api("repos/foo/bar/commits/master", sha: "foo")
      fire("master").must_equal ["foo"]
    end
  end

  describe :repo_compare do
    let(:project) { Project.new(repository_url: 'ssh://git@github.com:foo/bar.git') }

    def fire(a, b)
      Samson::Hooks.fire(:repo_compare, project, a, b)
    end

    only_callbacks_for_plugin :repo_compare

    it "skips non-github" do
      project.stubs(:github?).returns(false)
      fire("a", "b").must_equal [nil]
    end

    it "resolves a refernece" do
      stub_github_api("repos/foo/bar/compare/a...b", "x" => "y")
      fire("a", "b").map(&:to_h).must_equal [{x: "y"}]
    end

    # tests config/initializers/octokit.rb patch
    it "catches exception and returns NullComparison" do
      stub_github_api(
        "repos/foo/bar/compare/a...b",
        {},
        301,
        {'location': 'https://api.github.com/repos/foobar/bar/compare'}
      )

      assert_raises(Octokit::Middleware::RedirectLimitReached) { fire("a", "b") }.message.must_include(
        "too many redirects; last one to: https://api.github"
      )
    end
  end
end
