# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SamsonFlowdock::FlowdockService do
  let(:deploy) { deploys(:succeeded_test) }
  let(:service) { SamsonFlowdock::FlowdockService.new(deploy) }

  describe '#users' do
    with_env(FLOWDOCK_API_TOKEN: 'some-token')

    it "shows all users" do
      assert_request(
        :get, "https://api.flowdock.com/v1/users",
        to_return: {body: [{id: 1, nick: 'NICK', avatar: 'AVATAR', contact: 'CONTACT'}].to_json}
      ) do
        2.times do # check caching
          service.users.must_equal([{id: 1, name: "NICK", avatar: "AVATAR", type: "CONTACT"}])
        end
      end
    end

    it "shows nothing when flowdock fails to fetch users" do
      assert_request(:get, "https://api.flowdock.com/v1/users", to_timeout: []) do
        Rails.logger.expects(:error).with(includes('Error fetching flowdock users'))
        2.times do # check caching
          service.users.must_equal([])
        end
      end
    end

    it "shows nothing when api token is not configured" do
      with_env(FLOWDOCK_API_TOKEN: nil) do
        Rails.logger.expects(:error).with(
          'Set the FLOWDOCK_API_TOKEN env variable to enabled user mention autocomplete.'
        )
        2.times do # check caching
          service.users.must_equal([])
        end
      end
    end
  end

  describe '#notify_chat' do
    it 'notifies' do
      assert_request(:post, "https://api.flowdock.com/v1/messages/chat/TOKEN") do
        deploy.stage.flowdock_flows.build(token: 'TOKEN')
        service.notify_chat('Hello', ['tag'])
      end
    end
  end

  describe '#notify_inbox' do
    it 'notifies' do
      assert_request(:post, "https://api.flowdock.com/v1/messages/team_inbox/TOKEN") do
        deploy.stage.flowdock_flows.build(token: 'TOKEN')
        service.notify_inbox('Hello', 'It is me!', 'http://example.com')
      end
    end
  end
end
