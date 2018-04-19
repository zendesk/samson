# frozen_string_literal: true
require 'flowdock'

module SamsonFlowdock
  class FlowdockService
    def initialize(deploy)
      @deploy = deploy
    end

    # users in the format jquery mentions input needs
    # see _notify_buddy_box.html.erb
    def users
      Rails.cache.fetch(:flowdock_users, expires_in: 5.minutes, race_condition_ttl: 5) do
        if flowdock_api_token
          begin
            flowdock_client.get('/users').map do |user|
              {
                id: user['id'],
                name: user['nick'],
                avatar: user['avatar'],
                type: user['contact']
              }
            end
          rescue StandardError
            Rails.logger.error("Error fetching flowdock users (token invalid / flowdock down). #{$!.class}: #{$!}")
            []
          end
        else
          Rails.logger.error('Set the FLOWDOCK_API_TOKEN env variable to enabled user mention autocomplete.')
          []
        end
      end
    end

    def notify_chat(message, tags)
      chat_flow.push_to_chat(content: message, tags: tags)
    end

    def notify_inbox(subject, message, link)
      tags = ["deploy", stage.name.downcase]
      inbox_flow.push_to_team_inbox(subject: subject, content: message, tags: tags, link: link)
    end

    private

    delegate :stage, :user, to: :@deploy

    def flowdock_client
      @flowdock_client ||= Flowdock::Client.new(api_token: flowdock_api_token)
    end

    def inbox_flow
      @inbox_flow ||= Flowdock::Flow.new(
        api_token: tokens,
        source: "samson",
        from: {name: user.name, address: user.email}
      )
    end

    def chat_flow
      @chat_flow ||= Flowdock::Flow.new(api_token: tokens, external_user_name: 'Samson')
    end

    def tokens
      stage.flowdock_tokens
    end

    def flowdock_api_token
      ENV['FLOWDOCK_API_TOKEN']
    end
  end
end
