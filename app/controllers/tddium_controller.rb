class TddiumController < ActionController::Base
  skip_before_filter :login_users
  skip_before_filter :verify_authenticity_token

  rescue_from ActiveRecord::RecordNotFound do
    head :not_found
  end

  def create
    return head :ok if params[:status] != "passed"

    project = Project.find_by!(repository_url: params[:repository][:url])
    stages = project.webhook_stages_for_branch(params[:branch])
    tddium_user = User.find_or_create_by(name: "Tddium")
    deploy_service = DeployService.new(project, tddium_user)

    stages.each do |stage|
      deploy_service.deploy!(stage, params[:commit_id])
    end

    head :ok
  end
end
