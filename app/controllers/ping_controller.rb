# frozen_string_literal: true
class PingController < ApplicationController
  skip_around_action :login_user

  def show
    head :ok
  end

  private

  def force_ssl?
    false
  end
end
