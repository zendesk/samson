# frozen_string_literal: true
class LocksController < ApplicationController
  include CurrentProject

  before_action :require_project, if: :for_stage_lock?
  before_action :authorize_resource!

  def create
    attributes = params.require(:lock).permit(Lock::ASSIGNABLE_KEYS).merge(user: current_user)
    Lock.create!(attributes)
    redirect_back notice: 'Locked', fallback_location: root_path
  end

  def destroy
    lock.try(:soft_delete)
    redirect_back notice: 'Unlocked', fallback_location: root_path
  end

  protected

  def for_stage_lock?
    case action_name
    when 'create'
      (params[:lock] || {})[:resource_type] == "Stage"
    when 'destroy'
      lock.resource_type == "Stage"
    else
      raise 'Unsupported action'
    end
  end

  def lock
    @lock ||= Lock.find(params[:id])
  end

  # Overrides CurrentProject#require_project
  def require_project
    case action_name
    when 'create' then
      @project = Stage.find(params[:lock][:resource_id]).project
    when 'destroy' then
      @project = lock.resource.project
    else
      raise 'Unsupported action'
    end
  end
end
