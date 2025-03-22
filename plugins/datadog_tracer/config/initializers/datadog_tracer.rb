# frozen_string_literal: true
if SamsonDatadogTracer.enabled?

  SamsonDatadogTracer::IGNORED_URLS = Set[
    '/ping',
    '/cable',
  ].freeze

  require 'datadog'
  Datadog.configure do |c|
    c.agent.host = ENV['STATSD_HOST'] || '127.0.0.1'
    c.tags = {
      env:             ENV['RAILS_ENV'],
      'rails.version': Rails.version,
      'ruby.version':  RUBY_VERSION
    }

    c.service = 'samson'

    c.tracing.instrument :rails
    c.tracing.instrument :action_pack, service_name: 'samson-rails-controller'
    c.tracing.instrument :active_support, cache_service: 'samson-cache'
    c.tracing.instrument :active_record, service_name: 'samson-mysql'

    c.tracing.instrument :faraday, service_name: 'samson-faraday'
    c.tracing.instrument :dalli, service_name: 'samson-dalli'

    require 'aws-sdk-ecr'
    c.tracing.instrument :aws, service_name: 'samson-aws'
  end

  # Span Filters
  # Filter out the health checks, version checks, and diagnostics
  uninteresting_controller_filter = Datadog::Tracing::Pipeline::SpanFilter.new do |span|
    span.name == 'rack.request' &&
    SamsonDatadogTracer::IGNORED_URLS.any? { |path| span.get_tag('http.url').include?(path) }
  end

  Datadog::Tracing.before_flush(uninteresting_controller_filter)
end
