# frozen_string_literal: true
class LocksController < ApplicationController
  include CurrentProject
  include CurrentStage

  before_action :require_stage, if: :for_stage_lock?
  before_action :authorize_resource!

  def index
    _, locks = pagy(Lock, page: page, items: 1000)
    render json: {locks: locks}
  end

  def create
    new_lock = Lock.new(lock_params)
    if new_lock.save
      respond_to do |format|
        format.html { redirect_back notice: (new_lock.warning? ? 'Warned' : 'Locked'), fallback_location: root_path }
        format.json { render json: {lock: new_lock} }
      end
    else
      respond_to do |format|
        format.html { redirect_back flash: {error: format_errors(new_lock)}, fallback_location: root_path }
        format.json { render_json_error 422, new_lock.errors }
      end
    end
  end

  def destroy
    lock&.soft_delete(validate: false)
    respond_to do |format|
      format.html { redirect_back notice: 'Unlocked', fallback_location: root_path }
      format.json { head :ok }
    end
  end

  def destroy_via_resource
    Lock.where(
      resource_id: params.fetch(:resource_id).presence,
      resource_type: params.fetch(:resource_type).presence
    ).first!.soft_delete!(validate: false)
    head :ok
  end

  private

  def lock_params
    params.require(:lock).permit(
      :description,
      :resource_id,
      :resource_type,
      :warning,
      :delete_in,
      :delete_at
    ).merge(user: current_user)
  end

  def format_errors(object)
    object.errors.messages.values.flatten.join("\n")
  end

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

  # Overrides CurrentStage#require_stage
  def require_stage
    case action_name
    when 'create' then
      @stage = Stage.find(params[:lock][:resource_id])
    when 'destroy' then
      @stage = lock.resource
    else
      raise 'Unsupported action'
    end
  end
end
