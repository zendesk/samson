# frozen_string_literal: true
class Api::UsersController < Api::BaseController
  before_action :authorize_resource!

  def destroy
    user = User.where(id: params.require(:id)).first

    if user
      user.soft_delete!
      head :ok
    else
      head :not_found
    end
  end
end
