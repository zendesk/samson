# frozen_string_literal: true
require "warden/strategies/doorkeeper"
require "warden/action_dispatch_patch"

class Warden::Strategies::Doorkeeper < ::Warden::Strategies::Base
  include ActionDispatchPatch

  def valid?
    # Hack because we are not using ActionDispatch
    r = RequestObject.new(request)
    return unless request.content_type == 'application/json'
    return unless r.authorization.present?
    return unless r.authorization.start_with?("Bearer ")
    @token = ::Doorkeeper::OAuth::Token.authenticate(r, *Doorkeeper.configuration.access_token_methods)
    @token && @token.accessible? && @token.acceptable?(@scope)
  end
end

Warden::Strategies.add(:doorkeeper, Warden::Strategies::Doorkeeper)
