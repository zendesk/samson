# frozen_string_literal: true
class Api::LocksController < Api::BaseController
  before_action :authorize_resource!

  def index
    render json: paginate(Lock)
  end

  def create
    Lock.create!(params.require(:lock).permit(Lock::ASSIGNABLE_KEYS).merge(user: current_user))
    head :created
  end

  def destroy
    Lock.find(params.require(:id)).soft_delete!
    head :ok
  end
end
