# frozen_string_literal: true
# Web-UI users interacts with locks via buttons on other pages, so always redirect back to where they clicked the button
class LocksController < ResourceController
  before_action :set_resource, only: [:create, :destroy]
  before_action :authorize_resource!

  def create
    respond_to do |format|
      format.html do
        options =
          if @resource.save
            {notice: (@lock.warning? ? 'Warned' : 'Locked')}
          else
            {alert: @lock.errors.full_messages.join("\n")}
          end
        redirect_back(fallback_location: locks_path, **options)
      end
      format.json { super }
    end
  end

  def destroy
    respond_to do |format|
      format.html do
        @lock.soft_delete!(validate: false)
        redirect_back(fallback_location: locks_path, notice: "Removed!")
      end
      format.json { super }
    end
  end

  private

  def resource_params
    super.permit(
      :description,
      :resource_id,
      :resource_type,
      :warning,
      :delete_in,
      :delete_at
    ).merge(user: current_user)
  end

  def set_resource
    if action_name == 'destroy' && !params[:id]
      # allow destroying via a query, ideally remove this and support querying in index and then do a normal delete
      # NOTE: using .fetch instead of .require since we support "" as meaning "global"
      id = params.fetch(:resource_id).presence
      type = params.fetch(:resource_type).presence
      raise "global or exact are ok, but not just id or just type" if !type ^ !id
      assign_resource Lock.where(resource_id: id, resource_type: type).first!
    else
      super
    end
  end

  # TODO: make CurrentUser handle dynamic scopes and remove this
  def authorize_resource!
    unauthorized! unless can?(resource_action, controller_name.to_sym, @lock&.resource)
  end
end
