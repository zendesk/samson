class DeployContext
  include DataMapper::Resource

  has n, :tasks, :through => Resource
  has n, :plugins, :through => Resource

  property :id, Serial
end
