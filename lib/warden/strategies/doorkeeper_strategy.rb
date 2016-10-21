# frozen_string_literal: true
require "warden/strategies/doorkeeper"

# Strategy that allows login via OAuth baerer token
class Warden::Strategies::Doorkeeper < ::Warden::Strategies::Base
  KEY = :doorkeeper

  def valid?
    request.authorization.to_s.start_with?("Bearer ")
  end

  def authenticate!
    if !request.path.start_with?('/api/')
      custom! [400, {}, ["Only api can be used with OAuth tokens"]]
    else
      token = ::Doorkeeper::OAuth::Token.authenticate(request, :from_bearer_authorization)

      # TODO: put scope the action requires here ...
      if token&.accessible? && token.acceptable?(nil) && user = User.find_by_id(token.resource_owner_id)
        request.session_options[:skip] = true # do not store user in session
        success! user
      else
        Rails.logger.error "Doorman auth error"
        halt!
      end
    end
  end

  private

  def request
    ActionDispatch::Request.new(super.env)
  end
end

Warden::Strategies.add(Warden::Strategies::Doorkeeper::KEY, Warden::Strategies::Doorkeeper)
