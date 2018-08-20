# frozen_string_literal: true
module SamsonNewRelic
  class Engine < Rails::Engine
  end

  KEY = ENV['NEWRELIC_API_KEY'].presence

  def self.enabled?
    KEY
  end

  def self.tracer_enabled?
    !!ENV['NEW_RELIC_LICENSE_KEY']
  end

  def self.trace_method_execution_scope(scope_name)
    if tracer_enabled?
      NewRelic::Agent::MethodTracerHelpers.trace_execution_scoped("Custom/Hooks/#{scope_name}") do
        yield
      end
    else
      yield
    end
  end
end

Samson::Hooks.view :stage_form, "samson_new_relic/fields"
Samson::Hooks.view :deploy_tab_nav, "samson_new_relic/deploy_tab_nav"
Samson::Hooks.view :deploy_tab_body, "samson_new_relic/deploy_tab_body"

Samson::Hooks.callback :stage_permitted_params do
  {new_relic_applications_attributes: [:id, :name, :_destroy]}
end

Samson::Hooks.callback :stage_clone do |old_stage, new_stage|
  old_applications = old_stage.new_relic_applications.map do |app|
    app.attributes.except("id", "updated_at", "created_at")
  end
  new_stage.new_relic_applications.build(old_applications)
end

Samson::Hooks.callback :performance_tracer do |klass, methods|
  if SamsonNewRelic.tracer_enabled?
    klass.is_a?(Class) && klass.class_eval do
      include ::NewRelic::Agent::MethodTracer
      methods.each do |method|
        add_method_tracer method
      end
    end
  end
end

Samson::Hooks.callback :asynchronous_performance_tracer do |klass, method, options|
  if SamsonNewRelic.tracer_enabled?
    klass.is_a?(Class) && klass.class_eval do
      include ::NewRelic::Agent::Instrumentation::ControllerInstrumentation
      add_transaction_tracer method, options
    end
  end
end
