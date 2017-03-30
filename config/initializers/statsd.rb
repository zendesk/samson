# frozen_string_literal: true
require 'datadog/statsd'

class << Samson
  attr_accessor :statsd
end

raise "use STATSD_HOST and STATSD_PORT" if File.exist?("config/statsd.yml")
Samson.statsd = Datadog::Statsd.new(ENV['STATSD_HOST'], ENV['STATSD_PORT'])
Samson.statsd.namespace = "samson.app"

Samson.statsd.event "Startup", "Samson startup" if ENV['SERVER_MODE']

ActiveSupport::Notifications.subscribe("execute_shell.samson") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)

  tags = [event.payload[:project], event.payload[:stage]]

  Samson.statsd.histogram "execute_shell.time", event.duration, tags: tags
  Samson.statsd.event "Executed shell command".dup, event.payload[:command], tags: tags
  Samson.statsd.increment "execute_shells", tags: tags

  Rails.logger.debug("Executed shell command in %.2fms" % event.duration)
end

ActiveSupport::Notifications.subscribe("job.threads") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  Samson.statsd.gauge "job.threads", event.payload[:thread_count]
end

# basic web stats
ActiveSupport::Notifications.subscribe(/process_action.action_controller/) do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  controller = "controller:#{event.payload[:controller]}"
  action = "action:#{event.payload[:action]}"
  format = "format:#{event.payload[:format] || 'all'}"
  format = "format:all" if format == "format:*/*"
  status = event.payload[:status]
  tags = [controller, action, format]

  Samson.statsd.histogram "web.request.time", event.duration, tags: tags
  Samson.statsd.histogram "web.db_query.time", event.payload[:db_runtime], tags: tags
  Samson.statsd.histogram "web.view.time", event.payload[:view_runtime].to_i, tags: tags
  Samson.statsd.increment "web.request.status.#{status}", tags: tags
end
