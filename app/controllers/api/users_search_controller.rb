# frozen_string_literal: true
class Api::UsersSearchController < Api::BaseController
  before_action :authorize_resource!

  def index
    user = User.where(email: params.require(:email)).first
    if user
      render json: user
    else
      render json: {}, status: :not_found
    end
  end
end
