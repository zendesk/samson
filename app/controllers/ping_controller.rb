class PingController < ApplicationController
  skip_before_action :login_users

  def show
    head :ok
  end
end
