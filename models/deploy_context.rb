class DeployContext
  include DataMapper::Resource

  has n, :tasks, :through => :deploy_context_task
  has n, :plugins, :through => Resource

  property :id, Serial
end
