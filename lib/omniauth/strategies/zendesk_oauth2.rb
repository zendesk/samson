require 'omniauth-oauth2'

module OmniAuth
  module Strategies
    class ZendeskOAuth2 < OmniAuth::Strategies::OAuth2
      option :name, "zendesk"

      option :client_options,
        token_url: "/oauth/tokens",
        authorize_url: "/oauth/authorizations/new",
        site: "http://dev.localhost",
        ssl: { verify: !Rails.env.development? }

      uid { raw_info['id'] }

      info do
        {
          :name => raw_info['name'],
          :email => raw_info['email']
        }
      end

      extra do
        {
          'raw_info' => raw_info
        }
      end

      def callback_phase
        super.tap do
          token_id = access_token.get('/api/v2/oauth/tokens/current.json').parsed['token']['id']
          access_token.delete("/api/v2/oauth/tokens/#{token_id}.json")
        end
      end

      def raw_info
        @raw_info ||= access_token.get('/api/v2/users/me.json').parsed['user']
      end
    end
  end
end
