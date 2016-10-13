# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SlackWebhook do
  let(:webhook) { SlackWebhook.new(after_deploy: false) }

  describe "#validate_url" do
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

  describe "#deliver_for?" do
    let(:deploy) { deploys(:succeeded_test) }

    it "does not deliver when everything is disabled" do
      refute webhook.deliver_for?(:before_deploy, deploy)
      refute webhook.deliver_for?(:after_deploy, deploy)
      refute webhook.deliver_for?(:for_buddy, deploy)
    end

    it "deliver before when before hook is enabled" do
      webhook.before_deploy = true
      assert webhook.deliver_for?(:before_deploy, deploy)
    end

    it "deliver after when after hook is enabled" do
      webhook.after_deploy = true
      assert webhook.deliver_for?(:after_deploy, deploy)
    end

    it "delivers for for_buddy when for_buddy hooks is enabled" do
      webhook.for_buddy = true
      assert webhook.deliver_for?(:for_buddy, deploy)
    end

    it "fails with unknown hook" do
      assert_raises { webhook.deliver_for?(:foobar, deploy) }
    end

    describe "with only_on_failure" do
      before do
        webhook.before_deploy = true
        webhook.after_deploy = true
        webhook.only_on_failure = true
      end

      it "deliver after for failed deploy" do
        assert webhook.deliver_for?(:after_deploy, deploys(:failed_staging_test))
      end

      it "does not deliver after for successful deploy" do
        refute webhook.deliver_for?(:after_deploy, deploy)
      end

      it "delivers before for all deploys" do
        assert webhook.deliver_for?(:before_deploy, deploy)
      end
    end
  end
end
