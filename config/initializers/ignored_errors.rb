# frozen_string_literal: true

ignored = [
  'ActionController::InvalidAuthenticityToken',
  'ActionController::UnknownFormat',
  'ActionController::UnknownHttpMethod',
  'ActionController::UnpermittedParameters',
  'ActionController::ParameterMissing',
  'ActionController::RoutingError',
  'ActiveRecord::RecordNotFound',
]

Samson::Hooks.callback(:ignore_error) do |error_class_name|
  ignored.include?(error_class_name)
end

Rails.application.console do
  Samson::Hooks.callback(:ignore_error) do |_error_class_name|
    puts "Not sending errors to handler in console"
    true
  end
end
