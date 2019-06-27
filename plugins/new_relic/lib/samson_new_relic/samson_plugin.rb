# frozen_string_literal: true
module SamsonNewRelic
  class Engine < Rails::Engine
  end

  def self.find_api_key
    api_key = ENV['NEW_RELIC_API_KEY'].presence
    raise "Use NEW_RELIC_API_KEY, not NEWRELIC_API_KEY" if ENV['NEWRELIC_API_KEY'] && !api_key
    api_key
  end

  def self.setup_initializers
    if ['staging', 'production'].include?(Rails.env)
      require 'newrelic_rpm'
    else
      # avoids circular dependencies warning
      # https://discuss.newrelic.com/t/circular-require-in-ruby-agent-lib-new-relic-agent-method-tracer-rb/42737
      require 'new_relic/control'

      # needed even in dev/test mode
      require 'new_relic/agent/method_tracer'
    end
  end

  API_KEY = find_api_key

  def self.enabled?
    API_KEY
  end

  def self.tracer_enabled?
    !!ENV['NEW_RELIC_LICENSE_KEY'] # same key as the newrelic_rpm gem uses
  end

  def self.include_once(klass, mod)
    klass.include mod unless klass.include?(mod)
  end
end

# Railties need to be loaded before the application is initialized
SamsonNewRelic.setup_initializers

Samson::Hooks.view :stage_form, "samson_new_relic"
Samson::Hooks.view :deploy_tab_nav, "samson_new_relic"
Samson::Hooks.view :deploy_tab_body, "samson_new_relic"

Samson::Hooks.callback :stage_permitted_params do
  {new_relic_applications_attributes: [:id, :name, :_destroy]}
end

Samson::Hooks.callback :stage_clone do |old_stage, new_stage|
  old_applications = old_stage.new_relic_applications.map do |app|
    app.attributes.except("id", "updated_at", "created_at")
  end
  new_stage.new_relic_applications.build(old_applications)
end

Samson::Hooks.callback :trace_method do |klass, method|
  if SamsonNewRelic.tracer_enabled?
    SamsonNewRelic.include_once klass, ::NewRelic::Agent::MethodTracer
    klass.add_method_tracer method
  end
end

Samson::Hooks.callback :trace_scope do |scope|
  if SamsonNewRelic.tracer_enabled?
    ->(&block) { NewRelic::Agent::MethodTracerHelpers.trace_execution_scoped("Custom/Hooks/#{scope}", &block) }
  end
end

Samson::Hooks.callback :asynchronous_performance_tracer do |klass, method, options|
  if SamsonNewRelic.tracer_enabled?
    SamsonNewRelic.include_once klass, ::NewRelic::Agent::Instrumentation::ControllerInstrumentation
    klass.add_transaction_tracer method, options
  end
end
