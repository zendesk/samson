# http://www.rubydoc.info/gems/ddtrace/#Ruby_on_Rails

if ENV.fetch('ENABLE_DATADOG_APM', 'false') != 'false'
  require 'ddtrace'

  Rails.configuration.datadog_trace = {
    auto_instrument: true,
    auto_instrument_redis: true,
    default_service: 'samson',
    trace_agent_hostname: ENV.fetch('STATSD_HOST', 'localhost')
  }
end
