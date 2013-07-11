module JobsHelper
  def form_method(model)
    model.id ? "PUT" : "POST"
  end

  def task_ids
    @job.tasks.map(&:id) + (Task.all - @job.tasks).map(&:id)
  end

  def add_job_tasks
    priorities = []

    if params[:task_priorities] && !params[:task_priorities].empty?
      priorities = Rack::Utils.parse_nested_query(params[:task_priorities])
      priorities = priorities["tasks"]
    end

    params.fetch(:tasks, []).each do |task|
      @job.job_tasks.new(:task_id => task, :priority => priorities.index(task))
    end
  end
end
