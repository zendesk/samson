# frozen_string_literal: true
class LocksController < ApplicationController
  before_action :authorize_resource!

  def index
    _, locks = pagy(Lock, page: page, items: 1000)
    render json: {locks: locks}
  end

  def create
    if lock.save
      respond_to do |format|
        format.html { redirect_back notice: (lock.warning? ? 'Warned' : 'Locked'), fallback_location: root_path }
        format.json { render json: {lock: lock} }
      end
    else
      respond_to do |format|
        format.html do
          error = lock.errors.messages.values.flatten.join("\n")
          redirect_back flash: {error: error}, fallback_location: root_path
        end
        format.json { render_json_error 422, lock.errors }
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
    lock.soft_delete!(validate: false)
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

  def lock
    @lock ||= begin
      case action_name
      when 'create'
        Lock.new(lock_params)
      when 'destroy'
        Lock.find(params[:id])
      when 'destroy_via_resource'
        # NOTE: using .fetch instead of .require since we support "" as meaning "global"
        id = params.fetch(:resource_id).presence
        type = params.fetch(:resource_type).presence
        raise if !type ^ !id # global or exact are ok, but not just id or just type
        Lock.where(resource_id: id, resource_type: type).first!
      when 'index'
        nil
      else
        raise
      end
    end
  end

  # TODO: make CurrentUser handle dynamic scopes and remove this
  def authorize_resource!
    unauthorized! unless can?(resource_action, controller_name.to_sym, lock&.resource)
  end
end
