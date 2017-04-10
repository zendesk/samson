# frozen_string_literal: true
class GithubDeployment
  def initialize(deploy)
    @deploy = deploy
    @stage = @deploy.stage
    @project = @stage.project
  end

  # marks deployment as "Pending"
  # https://developer.github.com/v3/repos/deployments/#create-a-deployment
  def create
    GITHUB.create_deployment(
      @project.github_repo,
      @deploy.job.commit,
      payload: {
        deployer: @deploy.user.attributes.slice("id", "name", "email"),
        buddy: @deploy.buddy&.attributes&.slice("id", "name", "email"),
      },
      environment: @stage.name,
      description: @deploy.summary,
      production_environment: @stage.production?,
      auto_merge: false, # make deployments on merge commits not produce Octokit::Conflict and do not merge PRs
      required_contexts: [], # also create deployments when commit statuses show failure (CI failed)
      accept: "application/vnd.github.ant-man-preview+json" # special header so we can use production_environment field
    )
  end

  # marks deployment as "Succeeded" or "Failed"
  # https://developer.github.com/v3/repos/deployments/#create-a-deployment-status
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
