require 'slack-ruby-client'

module SamsonSlackWebhooks
  class SlackWebhooksService
    delegate :stage, :user, to: :@deploy

    def initialize(deploy)
      @deploy = deploy
    end

    def users
      slack_client.users_list().members.map do |user|
        {
          id: user['id'],
          name: user['name'],
          avatar: user['profile']['image_48'],
          type: 'contact'
        }
      end
    end

    def slack_client
      @slack_client ||= Slack::Web::Client.new(token: slack_api_token)
    end

    private

    def slack_api_token
      ENV['SLACK_API_TOKEN']
    end
  end
end
