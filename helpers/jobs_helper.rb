module JobsHelper
  def task_ids
    tasks = Task.all

    if @job.id
      mapped = @job.tasks.map do |task|
        tasks.index(task)
      end

      mapped += (tasks - @job.tasks).map {|task| tasks.index(task)}
    else
      (0..(tasks.size)).to_a
    end
  end

  def add_job_tasks
    priorities = []

    if params[:task_priorities] && !params[:task_priorities].empty?
      priorities = Rack::Utils.parse_nested_query(params[:task_priorities])
      priorities = priorities["tasks"].map(&:to_i)
    end

    # Can't use fetch as it isn't overriden for indifferent access
    params[:tasks] ||= []
    params[:tasks].map!(&:to_i)

    @job.job_tasks.delete_if do |task|
      !params[:tasks].include?(task.task_id)
    end

    (params[:tasks] - @job.job_tasks.map(&:task_id)).each do |task|
      @job.job_tasks.new(:task_id => task)
    end

    @job.job_tasks.each do |task|
      task.priority = priorities.index(task.task_id)
    end
  end
end
