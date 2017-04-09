# frozen_string_literal: true
class GithubDeployment
  def initialize(deploy)
    @deploy = deploy
    @stage = @deploy.stage
    @project = @stage.project
  end

  # marks deployment as "Pending"
  def create_github_deployment
    Rails.logger.info "Creating GitHub Deployment..."

    GITHUB.create_deployment(@project.github_repo, @deploy.reference, deployment_options)
  end

  # marks deployment as "Succeeded" or "Failed"
  def update_github_deployment_status(deployment)
    Rails.logger.info "Updating GitHub Deployment Status..."

    GITHUB.create_deployment_status(deployment.url, state, deployment_status_options)
  end

  private

  def deployment_options
    {
      payload: payload.to_json,
      environment: @stage.name,
      description: @deploy.summary
    }
  end

  def payload
    {
      deployer: @deploy.user.name,
      deployer_email: @deploy.user.email,
      buddy: @deploy.buddy_name,
      buddy_email: @deploy.buddy_email,
      production: @stage.production?
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
      raise "Unsupported deployment stage #{@deploy.job.status}"
    end
  end

  def deployment_status_options
    {
      target_url: url,
      description: @deploy.summary
    }
  end

  def url
    Rails.application.routes.url_helpers.project_deploy_url(@project, @deploy)
  end
end
