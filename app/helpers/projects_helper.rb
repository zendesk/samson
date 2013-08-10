module ProjectsHelper
  def valid_environments
    # Eventually consolidate this +
    # JobHistory validation
    # Should be gettable from zendesk_deployment
    %w{master1 master2 staging qa pod1:gamma pod1 pod2:gamma pod2}.map do |env|
      [env, env]
    end
  end

  def last_n(project)
    [project.job_histories.count, 5].min
  end

  def job_state_class(job)
    if job.failed?
      "failed"
    else
      "success"
    end
  end
end
