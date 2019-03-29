# frozen_string_literal: true

if key = ENV['AIRBRAKE_API_KEY']
  ActiveSupport.on_load(:samson_version) do |version|
    Airbrake.user_information_placeholder = ErrorNotifier::USER_INFORMATION_PLACEHOLDER
    Airbrake.user_information = # replaces replaces user_information_placeholder on 500 pages
      "<br/><br/>Error number: <a href='https://airbrake.io/locate/{{error_id}}'>{{error_id}}</a>" +
        ((link = ENV['HELP_LINK']) ? "<br/><br/>#{link}" : "")

    Airbrake.configure do |config|
      config.project_id = ENV.fetch('AIRBRAKE_PROJECT_ID')
      config.project_key = key

      config.app_version = version.first(7) if version
      raise 'This must run after config/initializers/ ' if Rails.application.config.filter_parameters.empty?
      config.blacklist_keys = Rails.application.config.filter_parameters

      # send correct errors even when something blows up during initialization
      config.environment = Rails.env
      config.ignore_environments = [:test, :development]

      # report in development:
      # - add AIRBRAKE_API_KEY to ENV
      # - add AIRBRAKE_PROJECT_ID to ENV
      # - set consider_all_requests_local = false in development.rb
      # - comment out add_filter below
      # - uncomment
      # config.ignore_environments = [:test]
    end

    # Ignore errors based on result of hook, so other parts of the code can interact with errors
    Airbrake.add_filter do |notice|
      notice.ignore! if notice[:errors].any? { |e| Samson::Hooks.fire(:ignore_error, e[:type]).any? }
    end
  end
end
