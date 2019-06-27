# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe OutboundWebhook do
  let(:webhook_attributes) do
    {
      stage: stages(:test_staging),
      project: projects(:test),
      url: "https://testing.com/deploys"
    }
  end
  let(:webhook) { OutboundWebhook.create(webhook_attributes) }

  describe '#create' do
    it 'creates the webhook' do
      assert OutboundWebhook.create(webhook_attributes)
    end

    it 'refuses to create a duplicate webhook' do
      OutboundWebhook.create!(webhook_attributes)

      refute_valid OutboundWebhook.new(webhook_attributes)
    end

    it "validates that url begins with http:// or https://" do
      refute_valid OutboundWebhook.new(webhook_attributes.merge(url: "/foobar"))
    end

    it 'recreates a webhook after soft_delete' do
      webhook = OutboundWebhook.create!(webhook_attributes)

      assert_difference 'OutboundWebhook.count', -1 do
        webhook.soft_delete!(validate: false)
      end

      assert_difference 'OutboundWebhook.count', +1 do
        OutboundWebhook.create!(webhook_attributes)
      end
    end
  end

  describe '#soft_delete!' do
    let(:webhook) { OutboundWebhook.create!(webhook_attributes) }

    before { webhook }

    it 'deletes the webhook' do
      assert_difference 'OutboundWebhook.count', -1 do
        webhook.soft_delete!(validate: false)
      end
    end

    it 'soft deletes the webhook' do
      assert_difference  'OutboundWebhook.with_deleted { OutboundWebhook.count} ', 0 do
        webhook.soft_delete!(validate: false)
      end
    end

    # We have validation to stop us from having multiple of the same webhook active.
    # lets ensure that same validation doesn't stop us from having multiple of the same webhook soft-deleted.
    it 'can soft delete duplicate webhooks' do
      assert_difference 'OutboundWebhook.count', -1 do
        webhook.soft_delete!(validate: false)
      end

      webhook2 = OutboundWebhook.create!(webhook_attributes)
      assert_difference 'OutboundWebhook.count', -1 do
        webhook2.soft_delete!(validate: false)
      end
    end
  end

  describe "#connection" do
    before do
      @webhook = OutboundWebhook.create!(selected_webhook)
      @connection = @webhook.send(:connection)
    end

    describe "with no authorization" do
      let(:selected_webhook) { webhook_attributes }

      it "builds a connection with the correct params" do
        refute_includes @connection.headers, 'Authorization'
      end
    end

    describe "with authorization" do
      let(:selected_webhook) { webhook_attributes.merge(username: "adminuser", password: "abc123") }

      it "builds a connection with the correct params" do
        assert_equal @connection.headers['Authorization'], 'Basic YWRtaW51c2VyOmFiYzEyMw=='
      end
    end
  end

  describe "#deliver" do
    let(:webhook) { OutboundWebhook.create!(webhook_attributes) }

    before do
      OutboundWebhook.stubs(:deploy_as_json).returns({})
    end

    it "posts" do
      assert_request :post, "https://testing.com/deploys", with: {body: "{}"} do
        assert webhook.deliver(Deploy.new)
      end
    end

    it "fails on bad response" do
      assert_request :post, "https://testing.com/deploys", to_return: {status: 400} do
        refute webhook.deliver(Deploy.new)
      end
    end
  end

  describe "#as_json" do
    it "does not show password" do
      webhook.password = '123'
      webhook.as_json.keys.wont_include 'password'
    end
  end

  describe ".deploy_as_json" do
    it "renders a deploy" do
      json = OutboundWebhook.deploy_as_json(deploys(:succeeded_test))
      json.keys.must_include 'id'
      json.keys.must_include 'user'
      json.keys.must_include 'project'
      json.keys.must_include 'stage'
    end
  end
end
