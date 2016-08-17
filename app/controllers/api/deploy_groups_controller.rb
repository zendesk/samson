# frozen_string_literal: true
class Api::DeployGroupsController < Api::BaseController
  before_action :ensure_enabled

  def index
    scope = current_project.present? ? stage.deploy_groups : DeployGroup.all
    render json: paginate(scope.sort_by(&:natural_order))
  end

  protected

  def stage
    current_project.stages.find(params[:id])
  end

  def ensure_enabled
    return if DeployGroup.enabled?
    render json: {message: "DeployGroups are not enabled."}, status: :precondition_failed
  end
end
