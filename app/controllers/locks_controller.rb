class LocksController < ApplicationController
  load_and_authorize_resource

  def create
    @lock.save!
    redirect_to :back, notice: "Locked"
  end

  def destroy
    @lock.try(:soft_delete)
    redirect_to :back, notice: "Unlocked"
  end

  private

  def lock_params
    params.require(:lock).
      permit(:description, :stage_id, :warning).
      merge(user: current_user)
  end
end
