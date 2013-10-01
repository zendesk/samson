require 'resque'

if ENV["REDISTOGO_URL"]
  uri = URI.parse(ENV["REDISTOGO_URL"])
  Resque.redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
else
  resque_config = YAML.load_file(Rails.root + 'config/resque.yml')[Rails.env]
  host, port = resque_config.split(":")
  Resque.redis = Redis.new(host: host, port: port, driver: :ruby)
end
