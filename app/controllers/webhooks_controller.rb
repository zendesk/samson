# frozen_string_literal: true
require 'samson/integration'

class WebhooksController < ApplicationController
  include CurrentProject

  before_action :authorize_project_deployer!

  def create
    webhook = current_project.webhooks.build(webhook_params)
    if webhook.save
      redirect_to project_webhooks_path(current_project), notice: "Webhook created!"
    else
      current_project.reload
      flash[:alert] = "Error saving webhook: #{webhook.errors.full_messages.join(", ")}"
      render :index
    end
  end

  def destroy
    webhook = current_project.webhooks.find(params[:id])
    webhook.soft_delete!

    redirect_to project_webhooks_path(current_project)
  end

  private

  def webhook_params
    params.require(:webhook).permit(:branch, :stage_id, :source)
  end
end
