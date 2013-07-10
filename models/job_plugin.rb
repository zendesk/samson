class JobPlugin
  include DataMapper::Resource

  belongs_to :plugin, :key => true
  belongs_to :job, :key => true

  property :position, Integer, :required => true
end
