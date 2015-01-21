require_relative '../test_helper'

describe FlowdockNotification do
  let(:project) { stub(name: "Glitter") }
  let(:user) { stub(name: "John Wu", email: "wu@rocks.com") }
  let(:stage) { stub(name: "staging", flowdock_tokens: ["x123yx"], project: project) }
  let(:deploy) { stub(summary: "hello world!", user: user) }
  let(:notification) { FlowdockNotification.new(stage, deploy) }
  let(:endpoint) { "https://api.flowdock.com/v1/messages/team_inbox/x123yx" }
  let(:chat_endpoint) { "https://api.flowdock.com/v1/messages/chat/x123yx" }

  before do
    FlowdockNotificationRenderer.stubs(:render).returns("foo")
  end

  it 'should render the default notification ' do
    notification.default_notification_content.must_include(":pray: #{deploy.user.name}")
  end

  describe 'buddy request' do
    it 'sends a buddy request for all Flowdock flows configured for the stage' do
      delivery = stub_request(:post, chat_endpoint)
      FlowdockNotification.any_instance.expects(:default_notification_content).never
      notification.buddy_request('This is the message displayed in the flows')
      assert_requested delivery
    end

    it 'should send the default notification message as a buddy request message if no message is provided' do
      delivery = stub_request(:post, chat_endpoint)
      FlowdockNotification.any_instance.expects(:default_notification_content).once.returns('message')
      notification.buddy_request(nil)
      assert_requested delivery
    end

    it 'should send the default notification message as a buddy request message if an empty message is provided' do
      delivery = stub_request(:post, chat_endpoint)
      FlowdockNotification.any_instance.expects(:default_notification_content).once.returns('message')
      notification.buddy_request('')
      assert_requested delivery
    end
  end

  it "notifies all Flowdock flows configured for the stage" do
    delivery = stub_request(:post, endpoint)
    notification.deliver

    assert_requested delivery
  end

  it "renders a nicely formatted notification" do
    stub_request(:post, endpoint)
    FlowdockNotificationRenderer.stubs(:render).returns("bar")
    notification.deliver

    content = nil
    assert_requested :post, endpoint do |request|
      body = Rack::Utils.parse_query(request.body)
      content = body.fetch("content")
    end

    content.must_equal "bar"
  end
end
