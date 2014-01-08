class SemaphoreController < ActionController::Base
  skip_before_filter :login_users
  skip_before_filter :verify_authenticity_token

  rescue_from ActiveRecord::RecordNotFound do
    head :not_found
  end

  def create
    project = Project.find(params[:token])
    stage = project.stages.first
    deploy_service = DeployService.new(project, stage, User.first)
    deploy = deploy_service.deploy!(params[:commit][:id])

    head :ok
  end
end
