# frozen_string_literal: true

# Strategy that allows login via email / token header
# DEPRECATED: use OAuth
class Warden::Strategies::BasicStrategy < Warden::Strategies::Base
  KEY = :basic

  def valid?
    @auth = ActionDispatch::Request.new(request.env).authorization.to_s[/^Basic (.*)/i, 1]
  end

  def authenticate!
    email, token = Base64.decode64(@auth).split(':', 2)

    if user = User.where(email: email).where(token: token).first
      request.session_options[:skip] = true # do not store user in session
      success! user
    else
      Rails.logger.error "Basic auth error for #{email}"
      halt!
    end
  end
end

Warden::Strategies.add(Warden::Strategies::BasicStrategy::KEY, Warden::Strategies::BasicStrategy)
