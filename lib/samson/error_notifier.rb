# frozen_string_literal: true

module Samson
  module ErrorNotifier
    USER_INFORMATION_PLACEHOLDER = "<!-- ERROR NOTIFIER -->"

    class << self
      def notify(exception, options = {})
        debug_info = Samson::Hooks.fire(:error, exception, options).compact.detect { |result| result.is_a?(String) }
        if ::Rails.env.test?
          message = "ErrorNotifier caught exception: #{exception.message}. Use ErrorNotifier.expects(:notify) to " \
            "silence in tests"
          raise RuntimeError, message, exception.backtrace
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
end
