require_relative '../test_helper'

SingleCov.covered!

describe Stage do
  let(:stage) { stages(:test_staging) }

  describe "#send_slack_webhook_notifications?" do
    it "does not send when there are no hooks" do
      stage.send_slack_webhook_notifications?.must_equal false
    end

    it "does not send when there are no hooks" do
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
end
