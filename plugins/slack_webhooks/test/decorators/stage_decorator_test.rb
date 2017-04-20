# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Stage do
  let(:stage) { stages(:test_staging) }
  let(:attributes) { {channel: "test", webhook_url: "http://slack.com/abcdef", stage_id: stage.id, after_deploy: true} }

  describe "#slack_webhooks" do
    it "assigns" do
      stage.attributes = {slack_webhooks_attributes: {0 => {webhook_url: 'xxxx'}}}
      stage.slack_webhooks.size.must_equal 1
    end

    it "does not assign without url" do
      stage.attributes = {slack_webhooks_attributes: {0 => {webhook_url: ''}}}
      stage.slack_webhooks.size.must_equal 0
    end
  end
end
