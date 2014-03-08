module JobsHelper
  def active?
    @job.active? && (JobExecution.find_by_id(@job.id) || JobExecution.enabled)
  end
end
