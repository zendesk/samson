# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SamsonSlackWebhooks do
  let(:deploy) { deploys(:succeeded_test) }
  let(:stage) { deploy.stage }

  describe :before_deploy do
    it "sends notification on before hook" do
      stage.stubs(:send_slack_webhook_notifications?).returns(true)
      SlackWebhookNotification.any_instance.expects(:deliver)
      Samson::Hooks.fire(:before_deploy, deploy, nil)
    end

    it "does not send notifications when disabled" do
      SlackWebhookNotification.any_instance.expects(:deliver).never
      Samson::Hooks.fire(:before_deploy, deploy, nil)
    end
  end

  describe :after_deploy do
    it "sends notification on after hook" do
      stage.stubs(:send_slack_webhook_notifications?).returns(true)
      SlackWebhookNotification.any_instance.expects(:deliver)
      Samson::Hooks.fire(:after_deploy, deploy, nil)
    end

    it "does not send notifications when disabled" do
      SlackWebhookNotification.any_instance.expects(:deliver).never
      Samson::Hooks.fire(:after_deploy, deploy, nil)
    end
  end

  describe :stage_clone do
    it "copies all attributes except id" do
      stage.slack_webhooks << SlackWebhook.new(webhook_url: 'http://example.com', after_deploy: true)
      new_stage = Stage.new
      Samson::Hooks.fire(:stage_clone, stage, new_stage)
      new_stage.slack_webhooks.map(&:attributes).must_equal [{
        "id" => nil,
        "webhook_url" => "http://example.com",
        "channel" => nil,
        "stage_id" => nil,
        "created_at" => nil,
        "updated_at" => nil,
        "before_deploy" => false,
        "after_deploy" => true,
        "for_buddy" => false,
        "only_on_failure" => false
      }]
    end
  end

  describe :stage_permitted_params do
    it "includes our params" do
      Samson::Hooks.fire(:stage_permitted_params).must_include(
        slack_webhooks_attributes: [
          :id, :webhook_url, :channel, :before_deploy, :after_deploy, :for_buddy, :only_on_failure, :_destroy
        ]
      )
    end
  end
end
