# frozen_string_literal: true

class WebhooksController < ResourceController
  include CurrentProject

  before_action :authorize_resource!
  before_action :set_resource, only: [:show, :edit, :update, :destroy, :new, :create]

  def index
    respond_to do |format|
      format.html
      format.json { render_as_json :webhooks, @project.webhooks }
    end
  end

  def create
    super(template: :index)
  end

  private

  def resource_path
    resources_path
  end

  def resources_path
    [@project, 'webhooks']
  end

  def resource_params
    super.permit(:branch, :source, :stage_id).merge(project: current_project)
  end
end
