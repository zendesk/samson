class JobPresenter
  def initialize(job, options = {})
    @job = job
    @options = options
  end

  def present
    return unless @job

    {
      id: @job.id,
      user_id: @job.user_id,
      project_id: @job.project_id,
      status: @job.status,
      commit: @job.commit,
      tag: @job.tag,
      created_at: @job.created_at,
      updated_at: @job.updated_at,
    }.as_json
  end
end
