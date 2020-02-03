# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SamsonAirbrakeHook::SamsonPlugin do
  describe :after_deploy do
    def notify
      Samson::Hooks.fire :after_deploy, deploy, stub(output: nil)
    end

    let(:project) { projects(:test) }
    let(:deploy) { deploys(:succeeded_test) }
    let!(:secret) { create_secret('global/global/global/airbrake_api_key') }

    before do
      deploy.stage.update_column(:notify_airbrake, true)
      DeployGroup.stubs(enabled?: true)
    end

    it "sends a notification" do
      assert_request(
        :post, "https://api.airbrake.io/deploys.txt", with: {
          body: {
            "api_key" => "MY-SECRET",
            "deploy" => {
              "rails_env" => "staging",
              "scm_revision" => "abcabcaaabcabcaaabcabcaaabcabcaaabcabca1",
              "local_username" => "Super Admin",
              "scm_repository" => "https://github.com/bar/foo",
            }
          }
        }
      ) { notify }
    end

    it "does not send notifications when deploy groups are disabled" do
      DeployGroup.expects(enabled?: false)
      notify
    end

    it "does not sends a notification when stage is disabled" do
      deploy.stage.update_column(:notify_airbrake, false)
      notify
    end

    it "does not sends a notification when deploy failed" do
      deploy.job.update_column(:status, 'pending')
      notify
    end

    describe "with multiple environments" do
      before { deploy.stage.deploy_groups << deploy_groups(:pod1) }

      it "sends multiple notifications" do
        Faraday.expects(:post).times(2)
        notify
      end

      it "uses the deploy group specific key" do
        secret.destroy!
        create_secret('global/global/pod1/airbrake_api_key') # other environment did not have a key
        Faraday.expects(:post)
        notify
      end
    end

    it "does not sends a notification when api key is unknown" do
      secret.destroy!
      notify
    end

    it "does not sends a notification when stage had no deploy groups" do
      deploy.stage.deploy_groups.clear
      notify
    end

    it "does not send notifications when environment name is not a proper env" do
      deploy.stage.deploy_groups.first.environment.update_column(:name, 'dsf ss sd')
      notify
    end
  end

  describe :stage_permitted_params do
    it "allows notify_airbrake" do
      Samson::Hooks.fire(:stage_permitted_params).must_include :notify_airbrake
    end
  end

  describe ".git_to_http" do
    it "converts git to http" do
      SamsonAirbrakeHook::Notification.send(:git_to_http, 'git@foo.com:a.git').must_equal 'https://foo.com/a'
    end

    it "converts ssh git to http" do
      SamsonAirbrakeHook::Notification.send(:git_to_http, 'ssh://git@foo.com:a.git').must_equal 'https://foo.com/a'
    end

    it "converts http git" do
      SamsonAirbrakeHook::Notification.send(:git_to_http, 'http://foo.com/a.git').must_equal 'http://foo.com/a'
    end
  end
end
