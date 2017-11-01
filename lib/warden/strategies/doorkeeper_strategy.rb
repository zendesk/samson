# frozen_string_literal: true

# Strategy that allows login via OAuth baerer token
class Warden::Strategies::Doorkeeper < ::Warden::Strategies::Base
  KEY = :doorkeeper

  def valid?
    request.authorization.to_s.start_with?("Bearer ")
  end

  def authenticate!
    token = ::Doorkeeper::OAuth::Token.authenticate(request, :from_bearer_authorization)
    requested_scopes = request.env.fetch('requested_oauth_scopes')

    if !token
      halt_json "Unable to find OAuth token"
    elsif !token.accessible?
      halt_json "OAuth token is expired"
    elsif !token.acceptable?(requested_scopes)
      halt_json "OAuth token needs scope #{requested_scopes.to_sentence(last_word_connector: ', or ')}"
    elsif !(user = User.find_by_id(token.resource_owner_id))
      halt_json "OAuth token belongs to deleted user #{token.resource_owner_id}"
    else
      token.update_column(:last_used_at, Time.now) unless token.last_used_at&.> 1.minutes.ago
      request.session_options[:skip] = true # do not store user in session
      success! user
    end
  end

  private

  def request
    ActionDispatch::Request.new(super.env)
  end

  def halt_json(message)
    custom! [401, {'Content-Type' => 'application/json'}, [{error: message}.to_json]]
  end
end

Warden::Strategies.add(Warden::Strategies::Doorkeeper::KEY, Warden::Strategies::Doorkeeper)
