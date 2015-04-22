require 'flowdock'

module SamsonFlowdock
  class FlowdockService
    delegate :stage, :user, to: :@deploy

    def initialize(deploy)
      @deploy = deploy
    end

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
      @flowdock_client ||= Flowdock::Client.new(api_token: flowdock_api_token)
    end

    def notify_chat(message, tags)
      chat_flow.push_to_chat(content: message, tags: tags)
    end

    def notify_inbox(subject, message, link)
      tags = ["deploy", stage.name.downcase]
      inbox_flow.push_to_team_inbox(subject: subject, content: message, tags: tags, link: link)
    end

    private

    def inbox_flow
      @flow ||= Flowdock::Flow.new(
        api_token: tokens,
        source: "samson",
        from: { name: user.name, address: user.email }
      )
    end

    def chat_flow
      @flow ||= Flowdock::Flow.new(api_token: tokens, external_user_name: 'Samson')
    end

    def tokens
      @deploy.stage.flowdock_tokens
    end

    def flowdock_api_token
      ENV['FLOWDOCK_API_TOKEN']
    end
  end
end
