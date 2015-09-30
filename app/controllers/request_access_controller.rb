class RequestAccessController < ApplicationController
  def send_email
    RequestAccessMailer.request_access_email(request.base_url, current_user).deliver_now
    flash[:success] = 'Access request email sent.'
    redirect_to :back
  end
end
