require 'samson/integration'

class WebhooksController < ApplicationController
  include ProjectLevelAuthorization

  before_action :authorize_project_deployer!

  def index
    @webhooks = current_project.webhooks
    @sources = Samson::Integration.sources
  end

  def new
    @webhooks = current_project.webhooks
  end

  def create
    current_project.webhooks.create!(webhook_params)

    redirect_to project_webhooks_path(current_project)
  end

  def destroy
    webhook = current_project.webhooks.find(params[:id])
    webhook.soft_delete!

    redirect_to project_webhooks_path(current_project)
  end

  def show
    @webhook = current_project.webhooks.find(params[:id])
  end

  private

  def webhook_params
    params.require(:webhook).permit(:branch, :stage_id, :source)
  end

end
