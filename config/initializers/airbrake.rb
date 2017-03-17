# frozen_string_literal: true
if defined?(Airbrake) && key = ENV['AIRBRAKE_API_KEY']
  Airbrake.user_information = # replaces <!-- AIRBRAKE ERROR --> on 500 pages
    "<br/><br/>Error number: <a href='https://airbrake.io/locate/{{error_id}}'>{{error_id}}</a>"

  Airbrake.configure do |config|
    config.project_id = ENV.fetch('AIRBRAKE_PROJECT_ID')
    config.project_key = key

    config.blacklist_keys = Rails.application.config.filter_parameters + ['HTTP_AUTHORIZATION']

    # send correct errors even when something blows up during initialization
    config.environment = Rails.env
    config.ignore_environments = [:test, :development]
    config.root_directory = Bundler.root.realpath # can be removed after https://github.com/airbrake/airbrake-ruby/pull/180

    # report in development:
    # - add development in application.rb airbrake check
    # - add AIRBRAKE_API_KEY to ENV
    # - add AIRBRAKE_PROJECT_ID to ENV
    # - set consider_all_requests_local = false in development.rb
    # - uncomment
    # config.ignore_environments = [:test]
  end

  ignored = [
    'ActionController::InvalidAuthenticityToken',
    'ActionController::UnknownFormat',
    'ActionController::UnknownHttpMethod',
    'ActionController::UnpermittedParameters',
    'ActiveRecord::RecordNotFound',
  ]
  Airbrake.add_filter do |notice|
    notice.ignore! if notice[:errors].any? { |error| ignored.include?(error[:type]) }
  end
else
  module Airbrake
    def self.notify(ex, *_args)
      if Rails.env.test?
        raise ex # tests have to use Airbrake.expects(:notify) to not hide unintented errors
      else
        Rails.logger.error "AIRBRAKE: #{ex.class} - #{ex.message} - #{ex.backtrace[0..5].join("\n")}"
        nil
      end
    end

    def self.notify_sync(*args)
      notify(*args)
    end

    def self.user_information
      "Nope"
    end
  end
end
