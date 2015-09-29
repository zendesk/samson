class RequestAccessController < ApplicationController
  def send_email
    flash[:notice] = 'About to send email.'
    redirect_to :back
  end
end
