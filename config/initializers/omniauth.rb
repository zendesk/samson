require 'omniauth'

OmniAuth.config.logger = Rails.logger

require 'omniauth/strategies/zendesk_oauth2'
require 'omniauth-github'

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :github,
    ENV["GITHUB_CLIENT_ID"],
    ENV["GITHUB_SECRET"],
    # need the repo spec for organizations teams
    # unfortunately, they do not have a readonly version
    scope: "user:email,repo"

  provider OmniAuth::Strategies::ZendeskOAuth2,
    "deployment",
    ENV["CLIENT_SECRET"],
    :scope => "users:read"
end
