# frozen_string_literal: true
class LocksController < ApplicationController
  include CurrentProject
  include CurrentStage

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

  def require_stage
    @resource_class = Stage
    @stage = find_resource
  end

  def require_project
    @resource_class = Project
    @project = find_resource
  end

  def find_resource
    case action_name
    when 'create' then
      @resource_class.find lock_params[:resource_id] if lock_params[:resource_type] == @resource_class.name
    when 'destroy' then
      lock.resource if lock.resource_type == @resource_class.name
    end
  end

  def lock
    @lock ||= Lock.find(params[:id])
  end

  def authorize_resource!
    unauthorized! unless can?(resource_action, controller_name.to_sym, current_stage || current_project)
  end
end
