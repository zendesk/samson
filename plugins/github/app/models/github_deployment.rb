# frozen_string_literal: true
class GithubDeployment
  def initialize(deploy)
    @deploy = deploy
    @stage = @deploy.stage
    @project = @stage.project
  end

  # marks deployment as "Pending"
  def create_github_deployment
    GITHUB.create_deployment(
      @project.github_repo,
      @deploy.reference,
      payload: {
        deployer: @deploy.user.name,
        deployer_email: @deploy.user.email,
        buddy: @deploy.buddy_name,
        buddy_email: @deploy.buddy_email,
        production: @stage.production?
      },
      environment: @stage.name,
      description: @deploy.summary
    )
  end

  # marks deployment as "Succeeded" or "Failed"
  def update_github_deployment_status(deployment)
    GITHUB.create_deployment_status(
      deployment.url,
      state,
      target_url: @deploy.url,
      description: @deploy.summary
    )
  end

  private

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
end
