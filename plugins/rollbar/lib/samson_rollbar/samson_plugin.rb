# frozen_string_literal: true

require 'rollbar'
require 'rollbar/user_informer'

module SamsonRollbar
  class Engine < Rails::Engine
  end
end

Samson::Hooks.callback :error do |exception, options|
  sync = options[:sync]
  message = options[:message]
  options = options.without(:sync, :message)
  data = Rollbar.error(exception, message, options)

  if sync
    Rollbar::Util.uuid_rollbar_url(data, Rollbar.configuration) if data.is_a?(Hash)
  else
    data
  end
end
