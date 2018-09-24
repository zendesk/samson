# frozen_string_literal: true
if SamsonDatadogTracer.enabled?

  SamsonDatadogTracer::IGNORED_URLS = Set[
    '/ping',
    '/cable',
  ].freeze

  require 'ddtrace'
  Datadog.configure do |c|
    # Tracer
    c.tracer(
      hostname:                ENV['STATSD_HOST'] || '127.0.0.1',
      tags: {
        env:                   ENV['RAILS_ENV'],
        'rails.version':       Rails.version,
        'ruby.version':        RUBY_VERSION
      }
    )

    c.use :rails,
      service_name: 'samson',
      controller_service: 'samson-rails-controller',
      cache_service: 'samson-cache',
      database_service: 'samson-mysql',
      distributed_tracing: true

    c.use :faraday, service_name: 'samson-faraday'
    c.use :dalli, service_name: 'samson-dalli'

    require 'aws-sdk-ecr'
    c.use :aws, service_name: 'samson-aws'
  end

  # Span Filters
  # Filter out the health checks, version checks, and diagnostics
  uninteresting_controller_filter = Datadog::Pipeline::SpanFilter.new do |span|
    span.name == 'rack.request' &&
    SamsonDatadogTracer::IGNORED_URLS.any? { |path| span.get_tag('http.url').include?(path) }
  end

  Datadog::Pipeline.before_flush(uninteresting_controller_filter)
end
