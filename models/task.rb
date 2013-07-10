class Task
  include DataMapper::Resource

  property :id, Serial
  property :name, String, :required => true
  property :command, String, :required => true
end
