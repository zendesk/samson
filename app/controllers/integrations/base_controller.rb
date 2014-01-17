class Integrations::BaseController < ApplicationController
  skip_before_filter :login_users
  skip_before_filter :verify_authenticity_token

  rescue_from ActiveRecord::RecordNotFound do
    head :not_found
  end

  def create
    return head(:ok) unless deploy?

    stages = project.webhook_stages_for_branch(branch)
    deploy_service = DeployService.new(project, user)

    stages.each do |stage|
      deploy_service.deploy!(stage, commit)
    end

    head :ok
  end

  protected

  def project
    @project ||= Project.find_by_token!(params[:token])
  end
end
