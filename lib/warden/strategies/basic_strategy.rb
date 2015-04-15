class Warden::Strategies::BasicStrategy < Warden::Strategies::Base
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

    if (user = User.where(email: email).where(token: token).includes(:starred_projects).first)
      success!(user)
    else
      halt!
    end
  end

  # ActionDispatch's
  def authorization
    @authorization ||= request.env['HTTP_AUTHORIZATION'] ||
      request.env['X-HTTP_AUTHORIZATION'] ||
      request.env['X_HTTP_AUTHORIZATION'] ||
      request.env['REDIRECT_X_HTTP_AUTHORIZATION']
  end
end

Warden::Strategies.add(:basic, Warden::Strategies::BasicStrategy)
