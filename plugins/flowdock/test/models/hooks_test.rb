require_relative '../test_helper'

describe "flowdock hooks" do
  let(:deploy) { deploys(:succeeded_test) }
  let(:stage) { deploy.stage }

  describe :before_deploy do
    it "sends notification on before hook" do
      stage.stubs(:send_flowdock_notifications?).returns(true)
      FlowdockNotification.any_instance.expects(:deliver)
      Samson::Hooks.fire(:before_deploy, deploy, nil)
    end

    it "does not send notifications when disabled" do
      FlowdockNotification.any_instance.expects(:deliver).never
      Samson::Hooks.fire(:before_deploy, deploy, nil)
    end
  end

  describe :after_deploy do
    it "sends notification on after hook" do
      stage.stubs(:send_flowdock_notifications?).returns(true)
      FlowdockNotification.any_instance.expects(:deliver)
      Samson::Hooks.fire(:after_deploy, deploy, nil)
    end

    it "does not send notifications when disabled" do
      FlowdockNotification.any_instance.expects(:deliver).never
      Samson::Hooks.fire(:after_deploy, deploy, nil)
    end
  end
end
