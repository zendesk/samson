require 'redis'

if ENV["REDISTOGO_URL"]
  uri = URI.parse(ENV["REDISTOGO_URL"])
  REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
else
  redis_config = YAML.load_file(Rails.root + 'config/redis.yml')[Rails.env]
  host, port = redis_config.split(":")
  REDIS = Redis.new(host: host, port: port, driver: :ruby)
end
