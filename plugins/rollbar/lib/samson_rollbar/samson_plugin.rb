# frozen_string_literal: true

require 'rollbar'
require 'rollbar/user_informer'

module SamsonRollbar
  class Engine < Rails::Engine
  end
end

Samson::Hooks.callback :project_created do |name|
  response = Faraday.post(
    Rollbar.configuration.web_base + '/api/1/projects',
    access_token: ENV['ROLLBAR_ACCOUNT_TOKEN'],
    name: name
  )

  if response.success?
    'Rollbar project created successfully'
  else
    'There was a problem creating a Rollbar project. Please create one manually.'
  end
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
