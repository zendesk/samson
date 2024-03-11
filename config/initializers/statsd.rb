# frozen_string_literal: true
require 'datadog/statsd'

class << Samson
  attr_accessor :statsd
end

raise "use STATSD_HOST and STATSD_PORT" if File.exist?("config/statsd.yml")
Samson.statsd = Datadog::Statsd.new(
  ENV['STATSD_HOST'] || '127.0.0.1',
  ENV['STATSD_PORT'] || '8125',
  logger: Rails.logger,
  namespace: 'samson.app',
  single_thread: Rails.env.test?
)

Samson.statsd.event "Startup", "Samson startup" if ENV['SERVER_MODE']

# tested via test/lib/samson/time_sum_test.rb
ActiveSupport::Notifications.subscribe("execute_job.samson") do |_, start, finish, _, payload|
  duration = 1000.0 * (finish - start)
  tags = [
    "project:#{payload.fetch(:project)}",
    "stage:#{payload.fetch(:stage)}",
  ]

  # only for deploys report if things were run in production
  production = payload.fetch(:production)
  tags << "production:#{production}" unless production.nil?

  # report if things were run with kubernetes
  kubernetes = payload.fetch(:kubernetes)
  tags << "kubernetes:#{kubernetes}" unless kubernetes.nil?

  Samson.statsd.timing "execute_shell.time", duration, tags: tags
  (payload[:parts] || {}).each do |part, time|
    Samson.statsd.timing "execute_shell.parts", time, tags: tags + ["part:#{part}"]
  end
  Rails.logger.info(payload.merge(total: duration, message: "Job execution finished"))
end

# report and log timing, plain names so git-grep works
[
  ["execute.command_executor.samson", "command_executor.execute", []],
  ["execute.terminal_executor.samson", "terminal_executor.execute", []],
  ["request.rest_client.samson", "rest_client.request", [:method]],
  ["request.vault.samson", "vault.request", [:method]],
  ["request.faraday.samson", "faraday.request", [:method]],
  ["wait_for_build.samson", "builds.time.wait_time", [:external, :project]]
].each do |topic, metric, tagged|
  ActiveSupport::Notifications.subscribe(topic) do |_, start, finish, _, payload|
    duration = 1000.0 * (finish - start)
    Rails.logger.debug(message: topic, duration: "#{duration.round(1)}ms", **payload)
    Samson.statsd.timing metric, duration, tags: tagged.map { |k| "#{k}:#{payload.fetch(k)}" }
  end
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

  # report if things were run with kubernetes
  kubernetes = payload.fetch(:kubernetes)
  tags << "kubernetes:#{kubernetes}" unless kubernetes.nil?

  payload.fetch(:cycle_time).each do |key, value|
    Samson.statsd.timing "jobs.deploy.cycle_time.#{key}", value * 1000, tags: tags
  end
  Samson.statsd.increment "jobs.#{payload.fetch(:type)}.#{payload.fetch(:status)}", tags: tags
end

ActiveSupport::Notifications.subscribe("system_stats.samson") do |*, payload|
  payload.each { |key, value| Samson.statsd.gauge key.to_s, value }
end

ActiveSupport::Notifications.subscribe("secret_cache.samson") do |*, payload|
  Samson.statsd.increment "secret_cache.#{payload[:action]}"
end

# basic web stats
ActiveSupport::Notifications.subscribe("process_action.action_controller") do |_, start, finish, _, payload|
  duration = 1000.0 * (finish - start)
  controller = "controller:#{payload.fetch(:controller)}"
  action = "action:#{payload.fetch(:action)}"
  format = "format:#{payload[:format] || 'all'}"
  format = "format:all" if format == "format:*/*"
  # Unauthorized and 500s have no status because it is a `throw`
  # samson/vendor/bundle/gems/actionpack-5.1.4/lib/action_controller/metal/instrumentation.rb:35
  status = payload[:status] || 'THR'
  tags = [controller, action, format]

  # db and view runtime are not set for actions without db/views
  # db_runtime does not work ... always returns 0 when running in server mode ... works fine locally and on console
  Samson.statsd.timing "web.request.time", duration, tags: tags
  Samson.statsd.timing "web.db_query.time", payload[:db_runtime].to_i, tags: tags
  Samson.statsd.timing "web.view.time", payload[:view_runtime].to_i, tags: tags
  Samson.statsd.increment "web.request.status.#{status}", tags: tags
end

# test: enable local exception backend (ex: plugins/samson_airbrake/config/initializers/airbrake.rb)
# will also report for errors ignored by config/initializers/ignored_errors.rb
Samson::Hooks.callback(:ignore_error) do |error_class_name|
  Samson.statsd.increment "errors.count", tags: ["class:#{error_class_name}"]
  false
end
