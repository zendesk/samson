class Job
  include DataMapper::Resource

  has n, :tasks, :through => :job_task
  has n, :plugins, :through => :job_plugin

  property :id, Serial
end
