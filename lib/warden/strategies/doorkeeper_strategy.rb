require "warden/strategies/doorkeeper"
require "warden/action_dispatch_patch"

class Warden::Strategies::Doorkeeper < ::Warden::Strategies::Base
  include ActionDispatchPatch

  def valid?
    # Hack because we are not using ActionDispatch
    r = RequestObject.new(request)
    return unless request.content_type == 'application/json'
    return unless r.authorization.present?

    # We want to stop authenticating if you didn't provide a full bearer token.
    # At this point we have already verified it's not basic auth.
    # w/o this the response would be a redirect to login. Not appropriate for api request.

    return unless r.authorization.start_with?("Bearer ")
    @token = ::Doorkeeper::OAuth::Token.authenticate(r, *Doorkeeper.configuration.access_token_methods)
    @token && @token.accessible? && @token.acceptable?(@scope)
  end
end

Warden::Strategies.add(:doorkeeper, Warden::Strategies::Doorkeeper)
