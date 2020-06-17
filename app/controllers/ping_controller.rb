# frozen_string_literal: true
class PingController < ApplicationController
  skip_before_action :login_user

  def show
    head :ok
  end

  def error
    raise('ping#error')
  end
end
