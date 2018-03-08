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
        message_body =
          if exception.is_a?(String)
            exception
          else
            "#{exception.class} - #{exception.message} - #{exception.backtrace[0..5].join("\n")}"
          end

        ::Rails.logger.error "ErrorNotifier: #{message_body}"
      end
      debug_info
    end
  end
end
