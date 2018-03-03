# frozen_string_literal: true

module ErrorNotifier
  USER_INFORMATION_PLACEHOLDER = "<!-- ERROR NOTIFIER -->"

  class << self
    def notify(exception, options = {})
      debug_info = Samson::Hooks.fire(:error, exception, options).compact.detect { |result| result.is_a?(String) }
      if ::Rails.env.test?
        raise exception # tests have to use ErrorNotifier.expects(:notify) to silence intended errors
      else
        # TODO: Don't spam logs twice if any exception plugin is enabled
        exception_message = "ErrorNotifier: #{exception.class} - #{exception.message} " \
          "- #{exception.backtrace[0..5].join("\n")}"
        ::Rails.logger.error exception_message
      end
      debug_info
    end
  end
end
