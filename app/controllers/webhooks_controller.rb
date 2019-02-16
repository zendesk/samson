# frozen_string_literal: true
require 'samson/integration'

class WebhooksController < ResourceController
  include CurrentProject

  before_action :authorize_resource!

  def create
    webhook = current_project.webhooks.build(webhook_params)
    respond_to do |format|
      format.html do
        if webhook.save
          redirect_to project_webhooks_path(current_project), notice: "Created!"
        else
          flash[:alert] = "Error saving webhook: #{webhook.errors.full_messages.join(", ")}"
          render :index
        end
      end
      format.json do
        webhook.save!
        render_as_json 'webhooks', webhook
      end
    end
  end

  private

  def search_resources
    @project.webhooks
  end

  def resources_path
    project_webhooks_path(current_project)
  end

  def resource_params
    super.permit(:branch, :source)
  end

  def webhook_params
    params.require(:webhook).permit(:branch, :stage_id, :source)
  end
end
