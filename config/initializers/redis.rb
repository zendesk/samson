require 'redis'

Redis.instance_eval do
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

Thread.abort_on_exception = !Rails.env.production?
Thread.main[:streams] = {}

thread = Thread.new do
  include ApplicationHelper # for render_log

  Redis.driver.psubscribe("deploy:*") do |on|
    on.pmessage do |pattern, channel, message|
      if (streams = Thread.main[:streams][channel])
        data = JSON.dump(msg: render_log(message).to_s)

        streams.each do |stream|
          stream.write("data: #{data}\n\n")
        end
      end
    end
  end
end

at_exit { thread.kill }
