class Integrations::BaseController < ApplicationController
  skip_before_filter :login_users
  skip_before_filter :verify_authenticity_token

  rescue_from ActiveRecord::RecordNotFound do
    head :not_found
  end

  def create
    create_new_release
    deploy_to_stages

    head :ok
  end

  protected

  def create_new_release
    if project.create_releases_for_branch?(branch)
      release_service = ReleaseService.new(project)
      release_service.create_release(commit: commit, author: user)
    end
  end

  def deploy_to_stages
    if deploy?
      stages = project.webhook_stages_for_branch(branch)
      deploy_service = DeployService.new(project, user)

      stages.each do |stage|
        deploy_service.deploy!(stage, commit)
      end
    end
  end

  def project
    @project ||= Project.find_by_token!(params[:token])
  end
end
