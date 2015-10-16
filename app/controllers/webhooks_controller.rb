require 'samson/integration'

class WebhooksController < ApplicationController
  include SamsonAudit

  before_action :authorize_deployer!
  before_action :find_project

  #Audit
  after_action only: [:create, :destroy] do
    audit(webhook)
  end

  def index
    @webhooks = @project.webhooks
    @sources = Samson::Integration.sources
  end

  def new
    @webhooks = @project.webhooks
  end

  def create
    @webhook = @project.webhooks.create!(webhook_params)
    redirect_to project_webhooks_path(@project)
  end

  def destroy
    webhook.soft_delete!
    redirect_to project_webhooks_path(@project)
  end

  def show
    webhook
  end

  private

  def find_project
    @project = Project.find_by_param!(params[:project_id])
  end

  def webhook_params
    params.require(:webhook).permit(:branch, :stage_id, :source)
  end

  def webhook
    @webhook ||= @project.webhooks.find(params[:id])
  end
end
