# frozen_string_literal: true
require 'samson/integration'

class OutboundWebhooksController < ApplicationController
  include CurrentProject

  before_action :authorize_project_deployer!

  def create
    webhook = OutboundWebhook.new(outbound_webhook_params.merge(project_id: current_project.id))

    if webhook.save
      flash.delete(:error)
      redirect_to project_webhooks_path(current_project)
    else
      flash[:error] = webhook.errors.full_messages.join(', ')
      @new_outbound_webhook = webhook
      render 'webhooks/index'
    end
  end

  def destroy
    outbound_webhook = current_project.outbound_webhooks.find(params[:id])
    outbound_webhook.soft_delete!

    redirect_to project_webhooks_path(current_project)
  end

  private

  def outbound_webhook_params
    params.require(:outbound_webhook).permit(:stage_id, :project_id, :url, :username, :password)
  end
end
