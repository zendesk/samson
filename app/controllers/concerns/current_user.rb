module CurrentUser
  extend ActiveSupport::Concern

  included do
    helper_method :current_user
    prepend_before_action :login_user
  end

  private

  def current_user
    @current_user ||= warden.user
  end

  # Called from SessionsController for OmniAuth
  def current_user=(user)
    warden.set_user(user, event: :authentication)
  end

  def logout!
    warden.logout
  end

  def login_user
    warden.authenticate!
  end

  def warden
    request.env['warden']
  end
end
