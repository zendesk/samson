# frozen_string_literal: true
if defined?(Airbrake)
  # TODO: needs to be updated to v5 + rewrite user_information logic
  # https://github.com/airbrake/airbrake/issues/636
  Airbrake.configure do |config|
    config.api_key = ENV['AIRBRAKE_API_KEY']
    config.user_information = # replaces <!-- AIRBRAKE ERROR --> on 500 pages
      "<br/><br/>Error number: <a href='https://airbrake.io/locate/{{error_id}}'>{{error_id}}</a>"

    # this will be blacklist_params in v5 ... does not support the full rails syntax
    config.params_filters = Rails.application.config.filter_parameters

    # report in development:
    # - uncomment
    # - add development in application.rb
    # - add AIRBRAKE_API_KEY to ENV
    # - set consider_all_requests_local in development.rb
    # config.development_environments = [:test]
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

    def self.configuration
      @configuration ||= Struct.new(
        :api_key, :host, :port, :proxy_host, :proxy_port, :proxy_user, :proxy_pass, :secure?
      ).new('fake-key')
    end
  end
end
