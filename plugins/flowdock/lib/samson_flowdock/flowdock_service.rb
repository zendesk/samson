require 'flowdock'

module SamsonFlowdock
  class FlowdockService

    def users
      flowdock_client.get('/users').map do |user|
        {
          id: user['id'],
          name: user['nick'],
          avatar: user['avatar'],
          type: user['contact']
        }
      end
    end

    def flowdock_client
      @flowdock_client ||= Flowdock::Client.new(api_token: ENV['FLOWDOCK_API_TOKEN'])
    end

    def notify(deploy, message)
      chat_flow = Flowdock::Flow.new(api_token: deploy.stage.flowdock_tokens, external_user_name: 'Samson')
      chat_flow.push_to_chat(:content => message, :tags => ['buddy-request'])
    end
  end
end
