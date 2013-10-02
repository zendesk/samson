require 'redis'

Redis.instance_eval do
  def publisher
    @publisher ||= driver
  end

  def subscriber
    @subscriber ||= driver
  end

  def driver
    if ENV["REDISTOGO_URL"]
      uri = URI.parse(ENV["REDISTOGO_URL"])
      Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
    elsif !Rails.env.production?
      redis_config = YAML.load_file(Rails.root.join('config/redis.yml'))[Rails.env]
      host, port = redis_config.split(":")
      Redis.new(host: host, port: port, driver: :ruby)
    end
  end
end
