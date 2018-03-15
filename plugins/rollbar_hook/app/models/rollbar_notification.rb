# frozen_string_literal: true
require 'faraday'

class RollbarNotification
  def initialize(webhook_url:, access_token:, environment:, revision:)
    @webhook_url = webhook_url
    @access_token = access_token
    @environment = environment
    @revision = revision
  end

  def deliver
    Rails.logger.info "Sending Rollbar notification..."
    response = Faraday.post(
      @webhook_url,
      access_token: @access_token,
      environment: @environment,
      revision: @revision,
      local_username: 'Samson'
    )

    if response.success?
      Rails.logger.info "Sent Rollbar notification"
    else
      Rails.logger.info "Failed to send Rollbar notification. HTTP #{response.status}: #{response.body}"
    end
  end
end
