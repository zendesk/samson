class LocksController < ApplicationController
  include ProjectLevelAuthorization

  before_action :authorize_admin!, if: :for_global_lock?

  before_action :require_project, unless: :for_global_lock?
  before_action :authorize_project_deployer!, unless: :for_global_lock?

  def create
    attributes = params.require(:lock).
      permit(:description, :stage_id, :warning).
      merge(user: current_user)
    Lock.create!(attributes)
    redirect_to :back, notice: 'Locked'
  end

  def destroy
    lock.try(:soft_delete)
    redirect_to :back, notice: 'Unlocked'
  end

  protected

  def for_global_lock?
    case action_name
    when 'create' then
      !params[:lock].try(:[], :stage_id) || !params[:lock][:stage_id].present?
    when 'destroy' then
      !lock.stage_id
    else
      raise 'Unsupported action'
    end
  end

  def lock
    @lock ||= Lock.find(params[:id])
  end

  #Overrides CurrentProject#require_project
  def require_project
    case action_name
    when 'create' then
      @project = Stage.find(params[:lock][:stage_id]).project
    when 'destroy' then
      @project = lock.stage.project
    else
      raise 'Unsupported action'
    end
  end
end
