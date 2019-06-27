# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SlackWebhook do
  let(:webhook) do
    SlackWebhook.new(
      on_deploy_success: true,
      webhook_url: 'http://example.com',
      stage: stages(:test_staging)
    )
  end

  it "is valid" do
    assert_valid webhook
  end

  describe "#validate_url" do
    it "is invalid without url" do
      webhook.webhook_url = nil
      refute_valid webhook
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

  describe "#validate_used" do
    it "is invalid when all types are deselected" do
      webhook.on_deploy_success = false

      refute_valid webhook
    end
  end

  describe "#cleanup_channel" do
    it "does not modify good channel" do
      webhook.channel = "test"
      assert_valid webhook
      webhook.channel.must_equal "test"
    end

    it "modifies bad channel" do
      webhook.channel = "#test"
      assert_valid webhook
      webhook.channel.must_equal "test"
    end
  end

  describe "#deliver_for?" do
    before { webhook.on_deploy_success = false }

    describe "with succeeded deploy" do
      let(:deploy) { deploys(:succeeded_test) }

      it "does not deliver when everything is disabled" do
        refute webhook.deliver_for?(:before_deploy, deploy)
        refute webhook.deliver_for?(:after_deploy, deploy)
        refute webhook.deliver_for?(:buddy_box, deploy)
        refute webhook.deliver_for?(:buddy_request, deploy)
      end

      it "deliver before when before hook is enabled" do
        webhook.before_deploy = true
        assert webhook.deliver_for?(:before_deploy, deploy)
      end

      it "delivers after when after hook for success is enabled" do
        webhook.on_deploy_success = true
        assert webhook.deliver_for?(:after_deploy, deploy)
      end

      it "does not deliver after when after hook for failure is enabled" do
        webhook.on_deploy_failure = true
        refute webhook.deliver_for?(:after_deploy, deploy)
      end

      it "delivers after when after hook for success and failure is enabled" do
        webhook.on_deploy_success = true
        webhook.on_deploy_failure = true
        assert webhook.deliver_for?(:after_deploy, deploy)
      end

      it "delivers for buddy_box when buddy_box hooks is enabled" do
        webhook.buddy_box = true
        assert webhook.deliver_for?(:buddy_box, deploy)
      end

      it "delivers for buddy_request when buddy_request hooks is enabled" do
        webhook.buddy_request = true
        assert webhook.deliver_for?(:buddy_request, deploy)
      end

      it "fails with unknown hook" do
        assert_raises { webhook.deliver_for?(:foobar, deploy) }.message.must_equal "Unknown phase :foobar"
      end
    end

    describe "with failed deploy" do
      let(:deploy) { deploys(:failed_staging_test) }

      it "does not deliver when after hook for success is enabled" do
        webhook.on_deploy_success = true
        refute webhook.deliver_for?(:after_deploy, deploy)
      end

      it "delivers after when after hook for failure is enabled" do
        webhook.on_deploy_failure = true
        assert webhook.deliver_for?(:after_deploy, deploy)
      end

      it "delivers after when after hook for success and failure is enabled" do
        webhook.on_deploy_success = true
        webhook.on_deploy_failure = true
        assert webhook.deliver_for?(:after_deploy, deploy)
      end
    end
  end
end
