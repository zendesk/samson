# frozen_string_literal: true
from_cap = !defined?(Rails)
if from_cap || defined?(Airbrake)
  Airbrake.configure do |config|
    config.api_key = ENV['AIRBRAKE_API_KEY']
    config.user_information = # replaces <!-- AIRBRAKE ERROR --> on 500 pages
      "<br/><br/>Error number: <a href='https://airbrake.io/locate/{{error_id}}'>{{error_id}}</a>"
    # config.development_environments = [:test] # uncomment to report in development
  end
else
  module Airbrake
    def self.notify(ex, *_args)
      Rails.logger.error "AIRBRAKE: #{ex.class} - #{ex.message} - #{ex.backtrace[0..5].join("\n")}"
      nil
    end

    def self.notify_or_ignore(ex, *_args)
      notify(ex)
      nil
    end
  end
end
