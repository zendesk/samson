require 'omniauth-oauth2'

module OmniAuth
  module Strategies
    class ZendeskOAuth2 < OmniAuth::Strategies::OAuth2
      option :name, "zendesk"

      option :client_options,
        token_url: "/oauth/tokens",
        authorize_url: "/oauth/authorizations/new",
        site: ENV["ZENDESK_URL"] || "http://dev.localhost",
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

      protected

      def raw_info
        @raw_info ||= begin
          # Hack for ip restrictions on support.zendesk.com
          access_token.client.connection.headers["User-Agent"] = "Zendesk for iPhone"

          access_token.get('/api/v2/users/me.json').parsed['user'].tap do |user|
            if user['role'] == 'end-user'
              raise CallbackError.new(nil, "You do not have permission to view this page.")
            end
          end
        end
      end
    end
  end
end
