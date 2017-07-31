# frozen_string_literal: true
class Api::UsersController < Api::BaseController
  before_action :authorize_resource!

  def show
    render json: User.find(params.require(:id))
  end

  def show_via_resource
    user = User.search_by_criteria(
      search: "",
      email: params.fetch(:email).presence
    ).first!

    render json: user
  end

  def destroy
    User.find(params.require(:id)).soft_delete!
    head :ok
  end
end
