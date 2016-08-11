# frozen_string_literal: true
require 'uri'

module SlackAppHelper
  def slack_app_oauth_url(scopes)
    redirect_uri = URI.encode url_for(controller: :slack_app, action: :oauth, only_path: false)
    query = {
      client_id: ENV.fetch('SLACK_CLIENT_ID'),
      redirect_uri: redirect_uri,
      scope: scopes
    }
    "https://slack.com/oauth/authorize?#{query.to_query}"
  end
end
