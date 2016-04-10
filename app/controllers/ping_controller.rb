class PingController < ApplicationController
  skip_before_action :login_user

  def show
    head :ok
  end

  private
  def force_ssl?
    false
  end
end
