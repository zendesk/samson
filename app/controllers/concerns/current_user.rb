module CurrentUser
  extend ActiveSupport::Concern

  included do
    helper_method :logged_in?
    helper_method :current_user
  end

  def current_user
    @current_user ||= User.find(session[:user_id])
  rescue ActiveRecord::RecordNotFound
    session[:user_id] = nil
  end

  def current_user=(user)
    session[:user_id] = user.id
    @current_user = user
  end

  def logout!
    @current_user = nil
    reset_session
  end

  def logged_in?
    !!current_user
  end
end
