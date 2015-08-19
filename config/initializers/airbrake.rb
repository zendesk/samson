require 'airbrake'

if !defined?(Rails) || Rails.env.staging? || Rails.env.production?
  Airbrake.configure do |config|
    config.api_key = ENV['AIRBRAKE_API_KEY']
  end
else
  module Airbrake
    def self.notify(ex, *args)
      logger.error "AIRBRAKE: #{ex.message} - #{ex.backtrace[0..5].join("\n")}"
    end

    def self.notify_or_ignore(ex, *args)
      notify(ex)
    end
  end
end
