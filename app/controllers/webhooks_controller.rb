require 'samson/integration'

class WebhooksController < ApplicationController
  include CurrentProject
  include ProjectLevelAuthorization

  before_action do
    find_project(params[:project_id])
  end

  before_action :authorize_project_deployer!

  def index
    @webhooks = @project.webhooks
    @sources = Samson::Integration.sources
  end

  def new
    @webhooks = @project.webhooks
  end

  def create
    @project.webhooks.create!(webhook_params)

    redirect_to project_webhooks_path(@project)
  end

  def destroy
    webhook = @project.webhooks.find(params[:id])
    webhook.soft_delete!

    redirect_to project_webhooks_path(@project)
  end

  def show
    @webhook = @project.webhooks.find(params[:id])
  end

  private

  def webhook_params
    params.require(:webhook).permit(:branch, :stage_id, :source)
  end

end
