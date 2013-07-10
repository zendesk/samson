class Plugin
  include DataMapper::Resource

  property :id, Serial
  property :body, Text
end
