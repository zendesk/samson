class Api::V1::DeploysController < Api::V1::ApplicationController
  include CurrentProject

  before_filter :authorize_project_deployer!
  before_filter :ensure_reference_exists

  def create
    deploy_service = DeployService.new(current_user)
    @deploy = deploy_service.deploy!(current_stage, deploy_params)

    respond_to do |format|
      format.json do
        status = (@deploy.persisted? ? :created : :unprocessable_entity)
        render json: @deploy.to_json, status: status, location: [current_project, @deploy]
      end
    end
  end

  protected

  def current_stage
    @current_stage ||= current_project.stages.find_by_param!(params[:stage_id])
  end

  def ensure_reference_exists
    unless current_project_has_git_reference?
      Rails.logger.info(
        "reference '#{deploy_params[:reference]}' not found for #{current_project.name}"
      )
      render json: {}, status: :unprocessable_entity
    end
  end

  def current_project_has_git_reference?
    ReferencesService.
      new(current_project).
      find_git_references.
      include?(deploy_params[:reference])
  end

  def deploy_permitted_params
    [:reference, :stage_id] + Samson::Hooks.fire(:deploy_permitted_params)
  end

  def deploy_params
    params.require(:deploy).permit(deploy_permitted_params)
  end
end
