# frozen_string_literal: true
class Api::PingController < Api::BaseController
  before_action :authorize_resource!

  def index
    head :ok
  end
end
