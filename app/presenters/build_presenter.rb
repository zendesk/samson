class BuildPresenter
  def initialize(build, options = {})
    @build = build
    @options = options
  end

  def present
    return unless @build

    {
      id: @build.id,
      label: @build.label,
      description: @build.description,
      number: @build.number,
      project_id: @build.project_id,
      git_sha: @build.git_sha,
      git_ref: @build.git_ref,
      docker_image_id: @build.docker_image_id,
      docker_ref: @build.docker_ref,
      docker_repo_digest: @build.docker_repo_digest,
      docker_build_job_id: @build.docker_build_job_id,
      kubernetes_job: @build.kubernetes_job,
      created_by: user_presenter(@build.created_by).present,
      created_at: @build.created_at,
      updated_at: @build.updated_at
    }.as_json
  end

  private

  def user_presenter(user)
    UserPresenter.new(user)
  end
end
