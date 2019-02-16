# frozen_string_literal: true
require 'samson/integration'

class OutboundWebhooksController < ResourceController
  include CurrentProject

  prepend_before_action :authorize_project_deployer!, except: [:index]
  prepend_before_action :require_project

  def index
    respond_to do |format|
      format.json { render_as_json :webhooks, @project.outbound_webhooks }
    end
  end

  def create
    super(template: 'webhooks/index')
  end

  private

  def resource_path
    resources_path
  end

  def resources_path
    [@project, 'webhooks']
  end

  def resource_params
    super.permit(:stage_id, :url, :username, :password).merge(project: current_project)
  end
end
