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
      payload = {
        text: message,
        username: 'Samson',
        icon_url: "https://github.com/zendesk/samson/blob/master/app/assets/images/favicons/32x32_light.png?raw=true"
      }
      payload[:channel] = webhook.channel if webhook.channel?
      payload[:attachments] = attachments if attachments.present?

      begin
        response = Faraday.post(webhook.webhook_url, payload: payload.to_json)
        if response.status >= 300
          raise "Error: channel #{webhook.channel.inspect} #{response.status} #{response.body.to_s[0..100]}"
        end
      rescue Faraday::ClientError, RuntimeError => e
        Samson::ErrorNotifier.notify(
          e,
          webhook_id: webhook.id,
          channel: webhook.channel,
          url: webhook.stage&.url
        )
        Rails.logger.error("Could not deliver slack message to webhook #{webhook.id}: #{e.message}")
      end
    end

    private

    def slack_api_token
      ENV['SLACK_API_TOKEN']
    end
  end
end
