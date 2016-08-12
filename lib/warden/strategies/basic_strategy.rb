# frozen_string_literal: true
require "warden/action_dispatch_patch"

class Warden::Strategies::BasicStrategy < Warden::Strategies::Base
  include ActionDispatchPatch

  def valid?
    authorization.present? &&
      authorization =~ /^Basic/i
  end

  # Don't store user id in session
  def store?
    false
  end

  def authenticate!
    email, token = Base64.decode64(authorization.sub!(/^Basic /, '')).split(':')

    # This + store? change stops the Set-Cookie header from being sent
    request.session_options[:skip] = true

    if (user = User.where(email: email).where(token: token).first)
      success!(user)
    else
      Rails.logger.error("Auth Error for #{email}")
      halt!
    end
  end

  # ActionDispatch's
  def authorization
    RequestObject.new(request).authorization.to_s.dup
  end
end

Warden::Strategies.add(:basic, Warden::Strategies::BasicStrategy)
