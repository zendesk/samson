# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SamsonRollbarHook do
  let(:deploy) { deploys(:succeeded_test) }
  let(:stage) { deploy.stage }

  describe :after_deploy do
    it "sends notification on after hook" do
      stage.rollbar_webhooks.build(webhook_url: 'https://rollbar.com', access_token: 'token', environment: 'test')
      RollbarNotification.any_instance.expects(:deliver)
      Samson::Hooks.fire(:after_deploy, deploy, stub(output: nil))
    end
  end

  describe :stage_permitted_params do
    it "includes our params" do
      Samson::Hooks.fire(:stage_permitted_params).must_include(
        rollbar_webhooks_attributes: [
          :id, :_destroy,
          :webhook_url, :access_token, :environment
        ]
      )
    end
  end

  describe :stage_clone do
    it "copies all attributes except id" do
      stage.rollbar_webhooks = [RollbarWebhook.new(
        webhook_url: 'http://example.com',
        access_token: 'token',
        environment: 'test'
      )]
      new_stage = Stage.new
      Samson::Hooks.fire(:stage_clone, stage, new_stage)
      new_stage.rollbar_webhooks.map(&:attributes).must_equal [{
        "id" => nil,
        "webhook_url" => "http://example.com",
        "access_token" => "token",
        "environment" => "test",
        "stage_id" => nil,
        "created_at" => nil,
        "updated_at" => nil,
      }]
    end
  end
end
