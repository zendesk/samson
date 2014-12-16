class ApplicationController < ActionController::Base
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

  # Get parameters for lograge
  def append_info_to_payload(payload)
    super
    payload["params"] = request.params
  end

  def render_angular(ctrl: '', template: '')
    render 'shared/angular_wrapper', :locals =>  { controller: ctrl, template: template }
  end
end
