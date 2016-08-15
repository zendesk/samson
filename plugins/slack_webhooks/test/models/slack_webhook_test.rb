# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SlackWebhook do
  let(:webhook) { SlackWebhook.new }

  describe '#validate_url' do
    it "is valid with a valid url" do
      webhook.webhook_url = 'http://example.com'
      assert_valid webhook
    end

    it "is invalid with an invalid url" do
      webhook.webhook_url = 'http://example.co     m'
      refute_valid webhook
    end

    it "is invalid with garbadge" do
      webhook.webhook_url = 'ddsfdsfds'
      refute_valid webhook
    end
  end
end
