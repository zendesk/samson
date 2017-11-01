# frozen_string_literal: true
class LocksController < ApplicationController
  include CurrentProject

  before_action :require_project, if: :for_stage_lock?
  before_action :authorize_resource!

  def index
    render json: {locks: Lock.page(page).per(1000)}
  end

  def create
    lock = Lock.create!(
      params.require(:lock).
        permit(:description, :resource_id, :resource_type, :warning, :delete_in).
        merge(user: current_user)
    )
    respond_to do |format|
      format.html { redirect_back notice: 'Locked', fallback_location: root_path }
      format.json { render json: {lock: lock} }
    end
  end

  def destroy
    lock.try(:soft_delete)
    respond_to do |format|
      format.html { redirect_back notice: 'Unlocked', fallback_location: root_path }
      format.json { head :ok }
    end
  end

  def destroy_via_resource
    Lock.where(
      resource_id: params.fetch(:resource_id).presence,
      resource_type: params.fetch(:resource_type).presence
    ).first!.soft_delete!
    head :ok
  end

  protected

  def for_stage_lock?
    case action_name
    when 'create'
      (params[:lock] || {})[:resource_type] == "Stage"
    when 'destroy'
      lock.resource_type == "Stage"
    when 'index', 'destroy_via_resource'
      false
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
