class RequestAccessController < ApplicationController
  def send_email
    if ENV['REQUEST_ACCESS_FEATURE'].present?
      RequestAccessMailer.request_access_email(request.base_url, current_user).deliver_now
      flash[:success] = 'Access request email sent.'
      redirect_to :back
    else
      raise ActionController::RoutingError.new('Not Found')
    end
  end
end
