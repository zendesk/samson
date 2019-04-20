# frozen_string_literal: true

require 'airbrake'
require 'airbrake/user_informer'

module SamsonAirbrake
  class Engine < Rails::Engine
    def self.exception_debug_info(notice)
      return unless notice
      return 'Airbrake did not return an error id' unless id = notice['id']
      return 'Unable to find Airbrake url' unless url = Airbrake.user_information[/['"](http.*?)['"]/, 1]
      return 'Unable to find error_id placeholder' unless url.sub!('{{error_id}}', id)
      "Error #{url}"
    end
  end
end

Samson::Hooks.callback :error do |exception, sync: false, **options|
  if sync
    SamsonAirbrake::Engine.exception_debug_info(Airbrake.notify_sync(exception, options))
  else
    Airbrake.notify(exception, options)
  end
end
