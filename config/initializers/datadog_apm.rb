# frozen_string_literal: true
# http://www.rubydoc.info/gems/ddtrace/#Ruby_on_Rails

if ENV.fetch('DATADOG_ENABLE_APM', 'false') != 'false'
  require 'ddtrace'

  Rails.logger.info("Enabling Datadog APM tracer")

  Rails.configuration.datadog_trace = {
    auto_instrument: true,
    default_service: 'samson',
    default_controller_service: 'samson-rails-controller',
    default_cache_service: 'samson-cache',
    default_database_service: 'samson-mysql',
    trace_agent_hostname: ENV.fetch('STATSD_HOST', 'localhost'),
    tags: {
      project: 'samson'
    }
  }

  # Dalli instrumentation
  Datadog::Monkey.patch_module(:dalli)
  pin = Datadog::Pin.get_from(::Dalli)
  pin.service = 'samson-memcached'

  # Faraday instrumentation
  Datadog::Monkey.patch_module(:faraday)

  # SuckerPunch instrumentation
  require 'sucker_punch'
  Datadog::Monkey.patch_module(:sucker_punch)
  pin = Datadog::Pin.get_from(::SuckerPunch)
  pin.service = 'samson-queues'
end
