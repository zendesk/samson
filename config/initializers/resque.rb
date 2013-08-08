require 'resque'

resque_config = YAML.load_file(Rails.root + 'config/resque.yml')[Rails.env]
host, port = resque_config.split(":")
Resque.redis = Redis.new(host: host, port: port, driver: :ruby)

AsyncRedis = Redis.new(host: host, port: port, driver: :synchrony)
