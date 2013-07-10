class DeployContextTask
  include DataMapper::Resource

  belongs_to :task, :key => true
  belongs_to :deploy_context, :key => true

  property :position, Integer, :required => false, :default => 0
end
