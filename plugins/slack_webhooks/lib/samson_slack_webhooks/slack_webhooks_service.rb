# frozen_string_literal: true
module SamsonSlackWebhooks
  class SlackWebhooksService
    # users in the format jquery mentions input needs
    # see _notify_buddy_box.html.erb
    def users
      unless slack_api_token
        Rails.logger.error('Set the SLACK_API_TOKEN env variable to enabled user mention autocomplete.')
        return []
      end
      Rails.cache.fetch(:slack_users, expires_in: 5.minutes, race_condition_ttl: 5) do
        begin
          body = JSON.parse(Faraday.post("https://slack.com/api/users.list", token: slack_api_token).body)
          if body['ok']
            body['members'].map do |user|
              {
                id: user['id'],
                name: user['name'],
                avatar: user['profile']['image_48'],
                type: 'contact'
              }
            end
          else
            Rails.logger.error("Error fetching slack users: #{body['error']}")
            []
          end
        rescue StandardError
          Rails.logger.error("Error fetching slack users (token invalid / service down). #{$!.class}: #{$!}")
          []
        end
      end
    end

    def deliver_message_via_webhook(webhook:, message:, attachments:)
      payload = { text: message, username: 'samson-bot' }
      payload[:channel] = webhook.channel unless webhook.channel.blank?
      payload[:attachments] = attachments if attachments.present?

      Faraday.post(webhook.webhook_url, payload: payload.to_json)
    rescue Faraday::ClientError => e
      Rails.logger.error("Could not deliver slack message to webhook #{webhook.webhook_url}: #{e.message}")
    end

    private

    def slack_api_token
      ENV['SLACK_API_TOKEN']
    end
  end
end
