# frozen_string_literal: true
require 'samson/integration'

class WebhooksController < ResourceController
  include CurrentProject
  before_action :authorize_resource!

  private

  def search_resources
    @project.webhooks
  end

  def resource_path
    [@project, @webhook]
  end

  def resources_path
    project_webhooks_path(current_project)
  end

  def resource_params
    puts(current_project.inspect)
    puts("super is #{super}")
    super.permit(:branch, :source).merge(project: current_project)

    params.require(:webhook).permit(:branch, :stage_id, :source)
  end
end
