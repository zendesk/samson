class DeployPresenter
  def initialize(deploy, options = {})
    @deploy = deploy
    @options = options
  end

  def present
    return unless @deploy

    {
      id: @deploy.id,
      deployer:   user_presenter(@deploy.user).present,
      buddy:      user_presenter(@deploy.buddy).present,
      stage:      stage_presenter(@deploy.stage).present,
      job:        job_presenter(@deploy.job).present,
      build:      build_presenter(@deploy.build).present,
      reference:  @deploy.reference,
      release:    @deploy.release,
      kubernetes: @deploy.kubernetes,
      created_at: @deploy.created_at,
      started_at: @deploy.started_at,
      updated_at: @deploy.updated_at,
      deleted_at: @deploy.deleted_at
    }.as_json
  end

  private

  def user_presenter(user)
    UserPresenter.new(user)
  end

  def stage_presenter(stage)
    StagePresenter.new(stage)
  end

  def job_presenter(job)
    JobPresenter.new(job)
  end

  def build_presenter(build)
    BuildPresenter.new(build)
  end
end
