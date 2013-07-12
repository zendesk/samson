class Plugin
  include DataMapper::Resource

  property :id, Serial
  property :name, String
  property :content, Text
end
