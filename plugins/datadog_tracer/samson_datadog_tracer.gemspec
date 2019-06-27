# frozen_string_literal: true
Gem::Specification.new 'samson_datadog_tracer', '0.0.1' do |s|
  s.summary = 'Samson Datadog tracer plugin'
  s.authors = ['Sathish Subramanian']
  s.email = ['ssubramanian@zendesk.com']
  s.files = Dir['{config,lib}/**/*']

  s.add_runtime_dependency 'ddtrace'
end
