class JobTask
  include DataMapper::Resource

  belongs_to :task, :key => true
  belongs_to :job, :key => true

  property :priority, Integer, :required => false, :default => 0
end
