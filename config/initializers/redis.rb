require 'redis'

redis_config = YAML.load_file(Rails.root + 'config/redis.yml')[Rails.env]
host, port = redis_config.split(":")


