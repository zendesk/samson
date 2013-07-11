require 'data_mapper'
DataMapper.setup(:default, ENV['DATABASE_URL'] || "mysql://root@localhost/pusher_development")

Dir.glob(Bundler.root.join("models", "*.rb")).each do |file|
  require file
end

DataMapper.finalize
DataMapper.auto_upgrade!
