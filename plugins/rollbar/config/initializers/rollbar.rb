# frozen_string_literal: true

if token = ENV['ROLLBAR_ACCESS_TOKEN']
  Rollbar.configure do |config|
    config.access_token = token
    config.environment = Rails.env
    if url = ENV['ROLLBAR_URL']
      config.endpoint = url + '/api/1/item/'
    end
    if web_base = ENV['ROLLBAR_WEB_BASE'] || url
      config.web_base = web_base
    end
    config.use_thread # use threads for async notifications (waits for them at_exit)
    config.code_version = Rails.application.config.samson.version&.first(7)
    config.populate_empty_backtraces = true
    config.logger = Rails.logger

    # ignore errors we do not want to send to Rollbar
    config.before_process << proc do |options|
      "ignored" if Samson::Hooks.fire(:ignore_error, options[:exception].class.name).any?
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
