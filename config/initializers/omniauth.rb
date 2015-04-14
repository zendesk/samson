require 'omniauth'

OmniAuth.config.logger = Rails.logger

require 'omniauth-github'
require 'omniauth-google-oauth2'
require 'omniauth-gitlab'

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :github,
    ENV["GITHUB_CLIENT_ID"],
    ENV["GITHUB_SECRET"],
    :scope => "user:email",
    :client_options => {
      :site          => "https://#{Rails.application.config.samson.github.api_url}",
      :authorize_url => "https://#{Rails.application.config.samson.github.web_url}/login/oauth/authorize",
      :token_url     => "https://#{Rails.application.config.samson.github.web_url}/login/oauth/access_token",
    }

  provider OmniAuth::Strategies::GoogleOauth2,
    ENV["GOOGLE_CLIENT_ID"],
    ENV["GOOGLE_CLIENT_SECRET"],
    {
      :name => "google",
      :scope => "email,profile",
      :prompt => "select_account",
    }
  provider :gitlab,
    ENV["GITLAB_KEY"],
    ENV["GITLAB_SECRET"], 
    client_options: {
       site: "https://#{ENV['GITLAB_URL']}",
       authorize_url: '/oauth/authorize',
       token_url: '/oauth/token'
     }      


end
