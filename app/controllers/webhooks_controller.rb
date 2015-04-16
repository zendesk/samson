class WebhooksController < ApplicationController
  load_resource :project, find_by: :param
  load_and_authorize_resource through: :project

  def index
  end

  def new
    @webhooks = @project.webhooks
  end

  def create
    @webhook.save!

    redirect_to project_webhooks_path(@project)
  end

  def destroy
    @webhook.soft_delete!

    redirect_to project_webhooks_path(@project)
  end

  def show
  end

  private

  def webhook_params
    params.require(:webhook).permit(:branch, :stage_id)
  end

end
