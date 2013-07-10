class Task
  include DataMapper::Resource

  property :id, Serial
  property :name, String
  property :command, String
end
