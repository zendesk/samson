require_relative "job_task"

class Job
  include DataMapper::Resource

  has n, :tasks, :through => :job_tasks, :order => JobTask.priority
  has n, :plugins, :through => :job_plugins

  property :id, Serial
  property :name, String, :required => true
end
