class ApplicationController < ActionController::Base
  before_filter :pass_request

  rescue_from ActionController::ParameterMissing do
    redirect_to root_path
  end

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  # CurrentUser must be after protect_from_forgery,
  # so that authenticate! is called
  include CurrentUser
  include Authorization

  helper :flash

  protected

  def verified_request?
    warden.winning_strategy || super
  end

  def pass_request
    $request = request
  end

end
