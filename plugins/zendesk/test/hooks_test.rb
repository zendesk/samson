require_relative 'test_helper'

if SingleCov.running_single_file?
  SingleCov.covered! uncovered: 1, file: 'plugins/zendesk/lib/samson_zendesk/samson_plugin.rb'
end

describe "zendesk hooks" do
  let(:deploy) { deploys(:succeeded_test) }
  let(:stage) { deploy.stage }

  describe :after_deploy do
    it "sends Zendesk notifications if the stage has them enabled" do
      stage.stubs(:comment_on_zendesk_tickets?).returns(true)
      ZendeskNotification.any_instance.expects(:deliver)
      Samson::Hooks.fire(:after_deploy, deploy, nil)
    end

    it "does not send notifications when disabled" do
      ZendeskNotification.any_instance.expects(:deliver).never
      Samson::Hooks.fire(:after_deploy, deploy, nil)
    end
  end
end
