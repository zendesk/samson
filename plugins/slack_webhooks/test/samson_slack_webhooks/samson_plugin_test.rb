require_relative '../test_helper'

SingleCov.covered! unless defined?(Rake) # rake preloads all plugins

describe SamsonSlackWebhooks do
  let(:deploy) { deploys(:succeeded_test) }
  let(:project) { projects(:test) }
  let(:stage) { deploy.stage }

  describe :deploy_view do
    it "returns rendering params" do
      stage.stubs(:send_slack_buddy_request?).returns(true)
      stage.stubs(:slack_buddy_channels).returns(["ch1", "ch2"])
      AppRoutes.url_helpers.stubs(:slack_webhooks_notify_path).returns("http://localhost.com/deploy")
      SlackWebhookNotification.any_instance.stubs(:default_buddy_request_message).returns("message")
      SamsonSlackWebhooks::SlackWebhooksService.any_instance.stubs(:users).returns([{id: 123}])
      view = Object.new
      view.stubs(:render)
      view.expects(:render).with(
        "shared/notify_buddy_box",
        deploy: deploy, project: project,
        id_prefix: 'slack',
        send_buddy_request: true,
        form_path: 'http://localhost.com/deploy',
        title: 'Request a buddy via Slack',
        message: 'message',
        channels: 'ch1, ch2',
        users: [{id: 123}],
        channel_type: 'channels'
      )
      Samson::Hooks.render_views(:deploy_view, view, project: project, deploy: deploy)
    end
  end

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
      stage.slack_webhooks << SlackWebhook.new(webhook_url: 'http://example.com')
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
        "for_buddy" => false
      }]
    end
  end

  describe :stage_permitted_params do
    it "includes our params" do
      Samson::Hooks.fire(:stage_permitted_params).must_include(
        slack_webhooks_attributes: [:id, :webhook_url, :channel, :before_deploy, :after_deploy, :for_buddy, :_destroy]
      )
    end
  end
end
