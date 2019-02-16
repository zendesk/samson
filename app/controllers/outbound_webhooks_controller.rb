# frozen_string_literal: true
require 'samson/integration'

class OutboundWebhooksController < ResourceController
  include CurrentProject
  before_action :authorize_project_deployer!

  def create
    webhook = OutboundWebhook.new(resource_params)

    respond_to do |format|
      format.html do
        if webhook.save
          flash.delete(:error)
          redirect_to project_webhooks_path(current_project)
        else
          flash[:error] = webhook.errors.full_messages.join(', ')
          @new_outbound_webhook = webhook
          render 'webhooks/index'
        end
      end
      format.json do
        webhook.save!
        render_as_json :webhook, webhook
      end
    end
  end

  private

  def search_resources
    @project.outbound_webhooks
  end

  def resource_path
    [@project, 'webhooks']
  end

  def resources_path
    [@project, 'webhooks']
  end

  def resource_params
    params = [:stage_id, :project_id, :url, :username, :password]
    super.permit(params).merge(project: current_project)
  end
end
