require_relative '../test_helper'

SingleCov.covered! uncovered: 1 unless defined?(Rake) # rake preloads all plugins

describe SamsonFlowdock do
  let(:deploy) { deploys(:succeeded_test) }
  let(:project) { projects(:test) }
  let(:stage) { deploy.stage }

  describe :deploy_view do
    it "returns rendering params" do
      stage.stubs(:send_flowdock_notifications?).returns(true)
      stage.stubs(:enabled_flows_names).returns(["ch1", "ch2"])
      AppRoutes.url_helpers.stubs(:flowdock_notify_path).returns("http://localhost.com/deploy")
      FlowdockNotification.any_instance.stubs(:default_buddy_request_message).returns("message")
      SamsonFlowdock::FlowdockService.any_instance.stubs(:users).returns([{id: 123}])
      view = Object.new
      view.stubs(:render)
      view.expects(:render).with(
        "shared/notify_buddy_box",
        deploy: deploy, project: project,
        id_prefix: 'flowdock',
        send_buddy_request: true,
        form_path: 'http://localhost.com/deploy',
        title: 'Request a buddy via Flowdock',
        message: 'message',
        channels: 'ch1, ch2',
        users: [{id: 123}],
        channel_type: 'flows'
      )
      Samson::Hooks.render_views(:deploy_view, view, project: project, deploy: deploy)
    end
  end

  describe :before_deploy do
    it "sends notification on before hook" do
      stage.stubs(:send_flowdock_notifications?).returns(true)
      FlowdockNotification.any_instance.expects(:deliver)
      Samson::Hooks.fire(:before_deploy, deploy, nil)
    end

    it "does not send notifications when disabled" do
      FlowdockNotification.any_instance.expects(:deliver).never
      Samson::Hooks.fire(:before_deploy, deploy, nil)
    end
  end

  describe :after_deploy do
    it "sends notification on after hook" do
      stage.stubs(:send_flowdock_notifications?).returns(true)
      FlowdockNotification.any_instance.expects(:deliver)
      Samson::Hooks.fire(:after_deploy, deploy, nil)
    end

    it "does not send notifications when disabled" do
      FlowdockNotification.any_instance.expects(:deliver).never
      Samson::Hooks.fire(:after_deploy, deploy, nil)
    end
  end

  describe :stage_clone do
    it "copies all attributes except id" do
      stage.flowdock_flows << FlowdockFlow.new(name: "test", token: "abcxyz", enabled: false)
      new_stage = Stage.new
      Samson::Hooks.fire(:stage_clone, stage, new_stage)
      new_stage.flowdock_flows.map(&:attributes).must_equal [{
        "id" => nil,
        "name" => "test",
        "token" => "abcxyz",
        "stage_id" => nil,
        "created_at" => nil,
        "updated_at" => nil,
        "enabled" => false
      }]
    end
  end
end
