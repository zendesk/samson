# frozen_string_literal: true
class GithubDeployment
  def initialize(deploy)
    @deploy = deploy
    @stage = @deploy.stage
    @project = @stage.project
  end

  # marks deployment as "Pending"
  def create
    GITHUB.create_deployment(
      @project.github_repo,
      @deploy.job.commit,
      payload: {
        deployer: @deploy.user.attributes.slice("id", "name", "email"),
        buddy: @deploy.buddy&.attributes&.slice("id", "name", "email"),
        production: @stage.production?
      },
      environment: @stage.name,
      description: @deploy.summary
    )
  rescue Octokit::Conflict
    nil # cannot create new deployments on commits that were tagged
  end

  # marks deployment as "Succeeded" or "Failed"
  def update(deployment)
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
      raise ArgumentError, "Unsupported deployment stage #{@deploy.job.status}"
    end
  end
end
