# frozen_string_literal: true

if token = ENV['ROLLBAR_ACCESS_TOKEN']
  Rollbar.configure do |config|
    config.access_token = token
    config.environment = Rails.env
    config.endpoint = ENV.fetch('ROLLBAR_URL') + '/api/1/item/' if ENV.fetch('ROLLBAR_URL')
    config.web_base = ENV.fetch('ROLLBAR_WEB_BASE') if ENV.fetch('ROLLBAR_WEB_BASE')
    config.use_thread # use threads for async notifications (waits for them at_exit)
    config.code_version = Rails.application.config.samson.version&.first(7)
    config.populate_empty_backtraces = true
    config.logger = Rails.logger
    config.scrub_fields |= Rails.application.config.filter_parameters + ['HTTP_AUTHORIZATION']
    config.enabled = true

    # ignore errors we do not want to send to Rollbar
    config.before_process << proc do |options|
      raise Rollbar::Ignore if Samson::Hooks.fire(:ignore_error, options[:exception].class.name).any?
    end

    Rollbar::UserInformer.user_information_placeholder = ErrorNotifier::USER_INFORMATION_PLACEHOLDER
    Rollbar::UserInformer.user_information = <<~HTML
      <br/><br/>
      <a href="#{Rollbar.notifier.configuration.web_base}/instance/uuid?uuid={{error_uuid}}">
        View error {{error_uuid}} on Rollbar
      </a>
    HTML
  end
end
