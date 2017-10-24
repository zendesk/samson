# frozen_string_literal: true
class Api::LocksController < Api::BaseController
  before_action :authorize_resource!

  def index
    render json: {locks: paginate(Lock)}
  end

  def create
    lock = Lock.create!(params.require(:lock).permit(Lock::ASSIGNABLE_KEYS).merge(user: current_user))
    render json: {lock: lock}
  end

  def destroy
    Lock.find(params.require(:id)).soft_delete!
    head :ok
  end

  def destroy_via_resource
    lock = Lock.where(
      resource_id: params.fetch(:resource_id).presence,
      resource_type: params.fetch(:resource_type).presence
    ).first!
    lock.soft_delete!
    head :ok
  end
end
