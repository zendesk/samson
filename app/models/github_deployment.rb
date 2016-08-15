# frozen_string_literal: true
class GithubDeployment
  DEPLOYMENTS_PREVIEW_MEDIA_TYPE = "application/vnd.github.cannonball-preview+json"

  def initialize(deploy)
    @deploy = deploy
    @stage = @deploy.stage
    @project = @stage.project
  end

  def create_github_deployment
    Rails.logger.info "Creating GitHub Deployment..."

    GITHUB.create_deployment(@project.github_repo, @deploy.reference, deployment_options)
  end

  def update_github_deployment_status(deployment)
    Rails.logger.info "Updating GitHub Deployment Status..."

    GITHUB.create_deployment_status(deployment.url, state, deployment_status_options)
  end

  private

  def deployment_options
    {
      accept: DEPLOYMENTS_PREVIEW_MEDIA_TYPE,
      force: true,
      payload: {deployer: @deploy.user.name}.to_json,
      environment: @stage.name,
      description: @deploy.summary
    }
  end

  def state
    if @deploy.succeeded?
      'success'
    elsif @deploy.errored?
      'error'
    elsif @deploy.failed?
      'failure'
    else
      'pending'
    end
  end

  def deployment_status_options
    {
      accept: DEPLOYMENTS_PREVIEW_MEDIA_TYPE,
      target_url: url,
      description: @deploy.summary
    }
  end

  def url
    Rails.application.routes.url_helpers.project_deploy_url(@project, @deploy)
  end
end
