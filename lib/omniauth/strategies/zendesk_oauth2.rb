require 'omniauth-oauth2'

module OmniAuth
  module Strategies
    class ZendeskOAuth2 < OmniAuth::Strategies::OAuth2
      option :name, "zendesk"

      option :client_options,
        token_url: "/oauth/tokens",
        authorize_url: "/oauth/authorizations/new",
        site: ENV["ZENDESK_URL"] || "http://dev.localhost",
        ssl: { verify: !Rails.env.development? },
        connection_options: {
          headers: {
            # Hack for IP restrictions on support
            "User-Agent" => "Zendesk for iPhone"
          }
        }

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

      protected

      def raw_info
        @raw_info ||= begin
          Rails.logger.info("Trying to find user with token #{access_token.inspect}")
          access_token.get('/api/v2/users/me.json').parsed['user']
        end
      end
    end
  end
end
