require 'statsd'

module Samson::StatsdLoader
  class << self
    def create
      config = config_from_env || config_from_file
      Statsd.new(config.fetch(:host), config.fetch(:port))
    end

    private

    def config_from_env
      return unless host = ENV['STATSD_HOST']
      return unless port = ENV['STATSD_PORT']
      {host: host, port: port.to_i}
    end

    def config_from_file
      YAML.load_file(Rails.root + 'config/statsd.yml').
        fetch(Rails.env).
        symbolize_keys
    end
  end
end

$statsd = Samson::StatsdLoader.create
$statsd.namespace = "samson.app"

if ENV['SERVER_MODE']
  $statsd.event "Startup", "Samson startup"
end

ActiveSupport::Notifications.subscribe("execute_shell.samson") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)

  tags = [event.payload[:project], event.payload[:stage]]

  $statsd.histogram "execute_shell.time", event.duration, tags: tags
  $statsd.event "Executed shell command", event.payload[:command], tags: tags
  $statsd.increment "execute_shells", tags: tags

  Rails.logger.debug("Executed shell command in %.2fms" % event.duration)
end

ActiveSupport::Notifications.subscribe("job.threads") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  $statsd.gauge "job.threads", event.payload[:thread_count]
end

# basic web stats
ActiveSupport::Notifications.subscribe /process_action.action_controller/ do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  controller = "controller:#{event.payload[:controller]}"
  action = "action:#{event.payload[:action]}"
  format = "format:#{event.payload[:format] || 'all'}"
  format = "format:all" if format == "format:*/*"
  status = event.payload[:status]
  tags = [controller, action, format]

  $statsd.histogram "web.request.time", event.duration, tags: tags
  $statsd.histogram "web.db_query.time", event.payload[:db_runtime], tags: tags
  $statsd.histogram "web.view.time", event.payload[:view_runtime].to_i, tags: tags
  $statsd.increment "web.request.status.#{status}", tags: tags
end
