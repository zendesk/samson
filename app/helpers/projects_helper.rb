module ProjectsHelper
  def job_state_class(job)
    if job.succeeded?
      "success"
    else
      "failed"
    end
  end
end
