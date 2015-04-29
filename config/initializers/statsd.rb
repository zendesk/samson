require 'statsd'

module StatsdLoader
  def self.create
    config = config_from_env || config_from_file
    raise('Could not initialize statsd by file or by ENV') if config.nil?
    Statsd.new(config[:host], config[:port])
  end

  def self.config_from_env
    if ENV['STATSD_HOST'] && ENV['STATSD_PORT']
      {
        host: ENV['STATSD_HOST'],
        port: ENV['STATSD_PORT'].to_i
      }
    end
  end

  def self.config_from_file
    config_file = Rails.root.join('config/statsd.yml')
    if File.exist?(config_file)
      config = YAML.load(File.read(config_file))[Rails.env]
      config.symbolize_keys if config
    end
  end
end

$statsd = StatsdLoader.create
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
  $statsd.histogram "web.view.time", event.payload[:view_runtime], tags: tags
  $statsd.increment "web.request.status.#{status}", tags: tags
end
