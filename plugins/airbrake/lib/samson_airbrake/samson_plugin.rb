# frozen_string_literal: true

require 'airbrake' unless ENV['PRECOMPILE'] # uncovered

module SamsonAirbrake
  class SamsonPlugin < Rails::Engine
    def self.exception_debug_info(notice)
      return unless notice
      return 'Airbrake did not return an error id' unless id = notice['id']
      "Error https://airbrake.io/locate/#{id}"
    end
  end
end

Samson::Hooks.callback :error do |exception, sync: false, **options|
  if sync
    SamsonAirbrake::SamsonPlugin.exception_debug_info(Airbrake.notify_sync(exception, options))
  else
    Airbrake.notify(exception, options)
  end
end
