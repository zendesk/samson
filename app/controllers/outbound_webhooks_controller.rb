# frozen_string_literal: true
require 'samson/integration'

class OutboundWebhooksController < ResourceController
  include CurrentProject

  before_action :authorize_project_deployer!, except: [:index]
  before_action :set_resource, only: [:show, :edit, :update, :destroy, :new, :create, :connect]

  # creation is done from project webhooks page
  def create
    super(template: 'webhooks/index')
  end

  def destroy
    if @stage # unlink (does not handle json or failure)
      @resource.outbound_webhook_stages.where(stage: @stage).destroy_all
      @resource.destroy! unless @resource.global?
      redirect_to project_webhooks_path(@stage.project), notice: "Deleted"
    else
      super
    end
  end

  def update
    super template: 'show'
  end

  def connect
    connection = OutboundWebhookStage.create(stage: @stage, outbound_webhook: @outbound_webhook)
    if connection.persisted?
      redirect_to resources_path, notice: "Added"
    else
      redirect_to resources_path, alert: connection.errors.full_messages.join(', ')
    end
  end

  private

  def search_resources
    scope = super
    if project_id = params[:project_id]
      stage_ids = Project.find_by_param!(project_id).stages.pluck(:id)
      ids = OutboundWebhookStage.where(stage_id: stage_ids).pluck(:outbound_webhook_id).uniq
      scope = scope.where(id: ids)
    end
    scope
  end

  def resource_path
    resources_path
  end

  def resources_path
    @project ? [@project, :webhooks] : super
  end

  def resource_params
    allowed = [:name, :url, :username, :password, :auth_type, :insecure, :before_deploy, :status_path, :disabled]
    allowed << :global if action_name == "create"
    permitted = super.permit(*allowed)
    permitted[:stages] = [@stage] if @stage && action_name == "create"
    permitted.delete :password if permitted[:password].blank? && permitted[:username].present?
    permitted
  end

  def require_project
    return unless stage_id = params[:stage_id] # not scoped -> need to be global deployer
    @stage = Stage.find(stage_id)
    @project = @stage.project
  end
end
