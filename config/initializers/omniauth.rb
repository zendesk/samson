# frozen_string_literal: true
OmniAuth.config.logger = Rails.logger

Rails.application.config.middleware.use OmniAuth::Builder do
  if Rails.application.config.samson.auth.github
    require 'omniauth-github'
    provider(
      :github,
      ENV.fetch("GITHUB_CLIENT_ID"),
      ENV.fetch("GITHUB_SECRET"),
      scope: "user:email",
      client_options: {
        site:          Rails.application.config.samson.github.api_url,
        authorize_url: "#{Rails.application.config.samson.github.web_url}/login/oauth/authorize",
        token_url:     "#{Rails.application.config.samson.github.web_url}/login/oauth/access_token"
      }
    )
  end

  if Rails.application.config.samson.auth.google
    require 'omniauth-google-oauth2'
    provider(
      OmniAuth::Strategies::GoogleOauth2,
      ENV.fetch("GOOGLE_CLIENT_ID"),
      ENV.fetch("GOOGLE_CLIENT_SECRET"),
      name:   "google",
      scope:  "email,profile",
      prompt: "select_account",
      hd: ENV['EMAIL_DOMAIN']
    )
  end

  if Rails.application.config.samson.auth.gitlab
    require 'omniauth-gitlab'
    provider(
      :gitlab,
      ENV.fetch("GITLAB_APPLICATION_ID"),
      ENV.fetch("GITLAB_SECRET"),
      client_options: {
        site: Rails.application.config.samson.gitlab.web_url,
        authorize_url: '/oauth/authorize',
        token_url: '/oauth/token'
      }
    )
  end

  if Rails.application.config.samson.auth.ldap
    require 'omniauth-ldap'

    provider(
      OmniAuth::Strategies::LDAP,
      title: Rails.application.config.samson.ldap.title,
      host: Rails.application.config.samson.ldap.host,
      port: Rails.application.config.samson.ldap.port,
      method: 'plain',
      base: Rails.application.config.samson.ldap.base,
      uid: Rails.application.config.samson.ldap.uid,
      bind_dn: Rails.application.config.samson.ldap.bind_dn,
      password: Rails.application.config.samson.ldap.password
    )
  end

  if Rails.application.config.samson.auth.bitbucket
    require 'omniauth-bitbucket'
    provider(
      :bitbucket,
      ENV.fetch('BITBUCKET_KEY'),
      ENV.fetch('BITBUCKET_SECRET')
    )
  end
end
