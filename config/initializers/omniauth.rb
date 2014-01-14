require 'omniauth'

OmniAuth.config.logger = Rails.logger

require 'omniauth-github'

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :github,
    ENV["GITHUB_CLIENT_ID"],
    ENV["GITHUB_SECRET"],
    scope: "user:email,repo"
end
