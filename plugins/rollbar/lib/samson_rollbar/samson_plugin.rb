# frozen_string_literal: true

require 'rollbar'
require 'rollbar/user_informer'

module SamsonRollbar
  class Engine < Rails::Engine
  end
end

Samson::Hooks.view :project_form, "samson_rollbar/fields"

Samson::Hooks.callback :project_permitted_params do
  [:rollbar_read_token]
end

Samson::Hooks.callback :error do |exception, options|
  sync = options[:sync]
  options = options.without(:sync)
  data = Rollbar.error(exception, options)

  if sync
    Rollbar::Util.uuid_rollbar_url(data, Rollbar.configuration) if data.is_a?(Hash)
  else
    data
  end
end
