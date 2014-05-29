class PingController < ApplicationController
  skip_before_filter :login_users

  def show
    head :ok
  end
end
