# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe OutboundWebhook do
  let(:webhook_attributes) { {url: "https://testing.com/deploys", auth_type: "None"} }
  let(:webhook) { OutboundWebhook.new(webhook_attributes) }

  describe '#validations' do
    it 'is valid' do
      assert_valid webhook
    end

    it "validates that url begins with http:// or https://" do
      webhook.url = "/foobar"
      refute_valid webhook
    end

    it "validates user+password for basic auth" do
      webhook.auth_type = "Basic"
      refute_valid webhook

      webhook.username = "U"
      refute_valid webhook

      webhook.password = "P"
      assert_valid webhook
    end

    it "validates password for token auth" do
      webhook.auth_type = "Token"
      refute_valid webhook

      webhook.password = "P"
      assert_valid webhook
    end

    it "validates auth type" do
      webhook.auth_type = "Wut"
      refute_valid webhook
    end
  end

  describe "#ssl?" do
    it "is ssl with https" do
      assert webhook.ssl?
    end

    it "is not ssl with http" do
      webhook.url = "http://sdfsf.com"
      refute webhook.ssl?
    end

    it "is not ssl with insecure" do
      webhook.insecure = true
      refute webhook.ssl?
    end
  end

  describe "#ensure_unused" do
    it "allows deletion when unused" do
      webhook.save!
      webhook.destroy!
    end

    it "does not allow deletion when used" do
      webhook.save!
      webhook.stages = [stages(:test_staging)]
      refute webhook.destroy
    end
  end

  describe "#connection" do
    let(:connection) { webhook.send(:connection) }

    it "does not add auth when not configured" do
      refute_includes connection.headers, 'Authorization'
    end

    it "adds basic auth" do
      webhook.auth_type = "Basic"
      webhook.username = "adminuser"
      webhook.password = "abc123"
      assert_equal connection.headers['Authorization'], 'Basic YWRtaW51c2VyOmFiYzEyMw=='
    end

    it "adds token auth" do
      webhook.auth_type = "Token"
      webhook.username = "adminuser"
      webhook.password = "abc123"
      assert_equal connection.headers['Authorization'], 'Token abc123'
    end

    it "fails on unsupported type" do
      webhook.auth_type = "Wut"
      assert_raises(ArgumentError) { connection }
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
