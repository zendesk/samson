# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Stage do
  let(:stage) { stages(:test_staging) }
  let(:attributes) { {channel: "test", webhook_url: "http://slack.com/abcdef", stage_id: stage.id, after_deploy: true} }

  describe "#send_slack_webhook_notifications?" do
    it "does not send when there are no hooks" do
      stage.send_slack_webhook_notifications?.must_equal false
    end

    it "sends when there are hooks" do
      stage.slack_webhooks.build
      stage.send_slack_webhook_notifications?.must_equal true
    end
  end

  describe "#slack_webhooks" do
    it "assigns" do
      stage.attributes = {slack_webhooks_attributes: {0 => {'webhook_url' => 'xxxx'}}}
      stage.slack_webhooks.size.must_equal 1
    end

    it "does not assign without url" do
      stage.attributes = {slack_webhooks_attributes: {0 => {'webhook_url' => ''}}}
      stage.slack_webhooks.size.must_equal 0
    end
  end

  describe "#slack_buddy_channels" do
    it "returns channels when for_buddy is true" do
      stage.slack_webhooks = [SlackWebhook.new(attributes.merge(for_buddy: true))]
      stage.slack_buddy_channels.must_equal ["test"]
    end

    it "does not return channels when for_buddy is false" do
      stage.slack_webhooks = [SlackWebhook.new(attributes.merge(for_buddy: false))]
      stage.slack_buddy_channels.size.must_equal 0
    end
  end

  describe "#send_slack_buddy_request?" do
    it "sends when there are hooks with for_buddy is true" do
      stage.slack_webhooks = [SlackWebhook.new(attributes.merge(for_buddy: true))]
      stage.send_slack_buddy_request?.must_equal true
    end

    it "does not send when there are no hooks with for_buddy is true" do
      stage.slack_webhooks = [SlackWebhook.new(attributes.merge(for_buddy: false))]
      stage.send_slack_buddy_request?.must_equal false
    end
  end
end
