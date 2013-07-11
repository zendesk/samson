class Job
  include DataMapper::Resource

  has n, :job_tasks, :order => [:priority.desc]
  has n, :tasks, :through => :job_tasks

  has n, :plugins, :through => :job_plugins

  property :id, Serial
  property :name, String, :required => true
end
