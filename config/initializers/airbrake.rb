from_cap = !defined?(Rails)
if from_cap || Rails.env.staging? || Rails.env.production?
  require 'airbrake'
  Airbrake.configure do |config|
    config.api_key = ENV['AIRBRAKE_API_KEY']
  end
else
  module Airbrake
    def self.notify(ex, *_args)
      Rails.logger.error "AIRBRAKE: #{ex.class} - #{ex.message} - #{ex.backtrace[0..5].join("\n")}"
    end

    def self.notify_or_ignore(ex, *_args)
      notify(ex)
    end
  end
end
