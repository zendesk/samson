require 'data_mapper'
DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{Bundler.root.join("pusher.db")}")

Dir.glob(Bundler.root.join("models", "*.rb")).each do |file|
  require file
end

DataMapper.finalize.auto_upgrade!
