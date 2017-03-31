# frozen_string_literal: true
require 'datadog/statsd'

class << Samson
  attr_accessor :statsd
end

raise "use STATSD_HOST and STATSD_PORT" if File.exist?("config/statsd.yml")
Samson.statsd = Datadog::Statsd.new(ENV['STATSD_HOST'], ENV['STATSD_PORT'])
Samson.statsd.namespace = "samson.app"

Samson.statsd.event "Startup", "Samson startup" if ENV['SERVER_MODE']

ActiveSupport::Notifications.subscribe("execute_job.samson") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  tags = ["project:#{event.payload.fetch(:project)}", "stage:#{event.payload.fetch(:stage)}"]
  Samson.statsd.histogram "execute_shell.time", event.duration, tags: tags
end

ActiveSupport::Notifications.subscribe("job_queue.samson") do |*, payload|
  payload.each { |key, value| Samson.statsd.gauge "job.#{key}", value }
end

ActiveSupport::Notifications.subscribe("system_stats.samson") do |*, payload|
  payload.each { |key, value| Samson.statsd.gauge key.to_s, value }
end

# basic web stats
ActiveSupport::Notifications.subscribe("process_action.action_controller") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  controller = "controller:#{event.payload.fetch(:controller)}"
  action = "action:#{event.payload.fetch(:action)}"
  format = "format:#{event.payload[:format] || 'all'}"
  format = "format:all" if format == "format:*/*"
  status = event.payload[:status] || 401 # unauthorized redirect/error has no status because it is a `throw`
  tags = [controller, action, format]

  # db and view runtime are not set for actions without db/views
  # db_runtime does not work ... always returns 0 when running in server mode ... works fine locally and on console
  Samson.statsd.histogram "web.request.time", event.duration, tags: tags
  Samson.statsd.histogram "web.db_query.time", event.payload[:db_runtime].to_i, tags: tags
  Samson.statsd.histogram "web.view.time", event.payload[:view_runtime].to_i, tags: tags
  Samson.statsd.increment "web.request.status.#{status}", tags: tags
end
