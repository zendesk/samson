class GithubDeployment
  def initialize(stage, deploy)
    @stage, @deploy = stage, deploy
    @project = @stage.project
  end

  def create_github_deployment
    Rails.logger.info "Creating Github Deployment..."

    GITHUB.create_deployment(@project.github_repo, @deploy.reference, deployment_options)
  end

  def update_github_deployment_status(deployment)
    Rails.logger.info "Updating Github Deployment Status..."

    GITHUB.create_deployment_status(deployment.url, state, deployment_status_options)
  end

  private

  def deployment_options
    {
      force: true,
      payload: {deployer: @deploy.user.name}.to_json,
      environment: @stage.name
      description: @deploy.summary
    }
  end

  def state
    case
    when @deploy.succeeded?
      'success'
    when @deploy.errored?
      'error'
    when @deploy.failed?
      'failure'
    else
      'pending'
    end
  end

  def deployment_status_options
    {
      target_url: url,
      description: @deploy.summary
    }
  end

  def url
    url_helpers.project_deploy_url(@project, @deploy)
  end

  def url_helpers
    Rails.application.routes.url_helpers
  end

end
