require 'redis'

redis_config = YAML.load_file(Rails.root.join('config/redis.yml'))[Rails.env]
host, port = redis_config.split(":")

Redis.define_singleton_method(:driver) do
  new(host: host, port: port, driver: :ruby)
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
