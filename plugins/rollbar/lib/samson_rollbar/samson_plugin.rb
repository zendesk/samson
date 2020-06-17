# frozen_string_literal: true

require 'rollbar'
require 'rollbar/user_informer'

module SamsonRollbar
  class SamsonPlugin < Rails::Engine
  end
end

Samson::Hooks.callback :error do |exception, sync: false, **options|
  data = Rollbar.warn(exception, options)

  if sync
    Rollbar::Util.uuid_rollbar_url(data, Rollbar.configuration) if data.is_a?(Hash)
  else
    data
  end
end
