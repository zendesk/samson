require 'slack-ruby-client'

module SamsonSlackWebhooks
  class SlackWebhooksService

    def initialize(deploy)
      @deploy = deploy
    end

    # users in the format jquery mentions input needs
    # see _notify_buddy_box.html.erb
    def users
      Rails.cache.fetch(:slack_users, expires_in: 5.minutes, race_condition_ttl: 5) do
        if slack_api_token
          begin
            slack_client.users_list.members.map do |user|
              {
                id: user['id'],
                name: user['name'],
                avatar: user['profile']['image_48'],
                type: 'contact'
              }
            end
          rescue StandardError
            Rails.logger.error("Error fetching slack users (token invalid / service down). #{$!.class}: #{$!}")
            []
          end
        else
          Rails.logger.error('Set the SLACK_API_TOKEN env variable to enabled user mention autocomplete.')
          []
        end
      end
    end

    private

    def slack_client
      @slack_client ||= Slack::Web::Client.new(token: slack_api_token)
    end

    def slack_api_token
      ENV['SLACK_API_TOKEN']
    end
  end
end
