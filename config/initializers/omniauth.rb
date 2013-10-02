require 'omniauth'

OmniAuth.config.logger = Rails.logger

require 'omniauth/strategies/zendesk_oauth2'

Rails.application.config.middleware.use OmniAuth::Builder do
  provider OmniAuth::Strategies::ZendeskOAuth2, "deployment", ENV["CLIENT_SECRET"],
    :scope => "read write"
end
