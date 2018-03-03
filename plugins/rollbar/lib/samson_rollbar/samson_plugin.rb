# frozen_string_literal: true

require 'rollbar'

module SamsonRollbar
  class Engine < Rails::Engine
    initializer "rollbar.user_informer" do |app|
      app.config.middleware.insert_before(::Rack::Runtime, SamsonRollbar::RollbarUserInformer)
    end
  end
end

Samson::Hooks.callback :error do |exception, options|
  sync = options[:sync]
  options = options.without(:sync)
  data = Rollbar.error(exception, options)

  if sync
    Rollbar::Util.uuid_rollbar_url(data, Rollbar.configuration)
  else
    data
  end
end
