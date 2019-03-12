# frozen_string_literal: true
require 'datadog/statsd'

class << Samson
  attr_accessor :statsd
end

raise "use STATSD_HOST and STATSD_PORT" if File.exist?("config/statsd.yml")
Samson.statsd = Datadog::Statsd.new(ENV['STATSD_HOST'] || '127.0.0.1', ENV['STATSD_PORT'] || '8125')
Samson.statsd.namespace = "samson.app"

Samson.statsd.event "Startup", "Samson startup" if ENV['SERVER_MODE']

ActiveSupport::Notifications.subscribe("execute_job.samson") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  tags = [
    "project:#{event.payload.fetch(:project)}",
    "stage:#{event.payload.fetch(:stage)}",
  ]

  # only for deploys report if things were run in production
  production = event.payload.fetch(:production)
  tags << "production:#{production}" unless production.nil?

  Samson.statsd.histogram "execute_shell.time", event.duration, tags: tags
end

ActiveSupport::Notifications.subscribe("job_queue.samson") do |*, payload|
  [[:deploys, true], [:jobs, false]].each do |(type, is_deploy)|
    metrics = payload.fetch(type)
    metrics.each { |key, value| Samson.statsd.gauge "job.#{key}", value, tags: ["deploy:#{is_deploy}"] }
  end
end

ActiveSupport::Notifications.subscribe("job_status.samson") do |*, payload|
  tags = [
    "project:#{payload.fetch(:project)}",
    "stage:#{payload.fetch(:stage)}",
  ]

  payload.fetch(:cycle_time).each do |key, value|
    Samson.statsd.histogram "jobs.deploy.cycle_time.#{key}", value, tags: tags
  end
  Samson.statsd.increment "jobs.#{payload.fetch(:type)}.#{payload.fetch(:status)}", tags: tags
end

ActiveSupport::Notifications.subscribe("system_stats.samson") do |*, payload|
  payload.each { |key, value| Samson.statsd.gauge key.to_s, value }
end

ActiveSupport::Notifications.subscribe("wait_for_build.samson") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  tags = [
    "project:#{event.payload.fetch(:project)}",
    "external:#{event.payload.fetch(:external)}"
  ]

  Samson.statsd.timing "builds.time.wait_time", event.duration, tags: tags
end

# basic web stats
ActiveSupport::Notifications.subscribe("process_action.action_controller") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  controller = "controller:#{event.payload.fetch(:controller)}"
  action = "action:#{event.payload.fetch(:action)}"
  format = "format:#{event.payload[:format] || 'all'}"
  format = "format:all" if format == "format:*/*"
  # Unauthorized and 500s have no status because it is a `throw`
  # samson/vendor/bundle/gems/actionpack-5.1.4/lib/action_controller/metal/instrumentation.rb:35
  status = event.payload[:status] || 'THR'
  tags = [controller, action, format]

  # db and view runtime are not set for actions without db/views
  # db_runtime does not work ... always returns 0 when running in server mode ... works fine locally and on console
  Samson.statsd.histogram "web.request.time", event.duration, tags: tags
  Samson.statsd.histogram "web.db_query.time", event.payload[:db_runtime].to_i, tags: tags
  Samson.statsd.histogram "web.view.time", event.payload[:view_runtime].to_i, tags: tags
  Samson.statsd.increment "web.request.status.#{status}", tags: tags
end

# test: enable local exception backend (ex: plugins/samson_airbrake/config/initializers/airbrake.rb)
# will also report for errors ignored by config/initializers/ignored_errors.rb
Samson::Hooks.callback(:ignore_error) do |error_class_name|
  Samson.statsd.increment "errors.count", tags: ["class:#{error_class_name}"]
  false
end
