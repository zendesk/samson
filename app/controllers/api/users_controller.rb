# frozen_string_literal: true
class Api::UsersController < Api::BaseController
  before_action :authorize_resource!

  def destroy
    User.find(params.require(:id)).soft_delete!
    head :ok
  end
end
