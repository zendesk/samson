# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! uncovered: 1

describe SamsonFlowdock do
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
      Samson::Hooks.fire(:after_deploy, deploy, stub(output: nil))
    end

    it "does not send notifications when disabled" do
      FlowdockNotification.any_instance.expects(:deliver).never
      Samson::Hooks.fire(:after_deploy, deploy, stub(output: nil))
    end
  end

  describe :stage_clone do
    it "copies all attributes except id" do
      stage.flowdock_flows << FlowdockFlow.new(name: "test", token: "abcxyz")
      new_stage = Stage.new
      Samson::Hooks.fire(:stage_clone, stage, new_stage)
      new_stage.flowdock_flows.map(&:attributes).must_equal [{
        "id" => nil,
        "name" => "test",
        "token" => "abcxyz",
        "stage_id" => nil,
        "created_at" => nil,
        "updated_at" => nil
      }]
    end
  end
end
