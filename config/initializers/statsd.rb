
require 'statsd'

config_file = Rails.root.join('config/statsd.yml')
raise "No such file: config/statsd.yml" unless File.exist?(config_file)

yml = YAML.load(File.read(config_file))
config_for_environment = yml[Rails.env]
raise "No Statsd configuration for Rails env #{Rails.env}" unless config_for_environment

$statsd = Statsd.new(config_for_environment['host'], config_for_environment['port'])
$statsd.namespace = "samson.app"

if ENV['SERVER_MODE']
  $statsd.event "Startup", "Samson startup"
end

ActiveSupport::Notifications.subscribe("execute_shell.samson") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)

  tags = [event.payload[:project], event.payload[:stage]]

  $statsd.histogram "execute_shell.time", event.duration, :tags => tags
  $statsd.event "Executed shell command", event.payload[:command], :tags => tags
  $statsd.increment "execute_shells", :tags => tags

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

  $statsd.histogram "web.request.time", event.duration, :tags => tags
  $statsd.histogram "web.db_query.time", event.payload[:db_runtime], :tags => tags
  $statsd.histogram "web.view.time", event.payload[:view_runtime], :tags => tags
  $statsd.increment "web.request.status.#{status}", :tags => tags
end
