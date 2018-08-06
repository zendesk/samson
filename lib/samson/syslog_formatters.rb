# frozen_string_literal: true

require 'syslog/logger'
module Syslog
  module Formatters
    class Json < Syslog::Logger::Formatter
      def call(severity, timestamp, _progname, message)
        {
          severity: severity,
          time: timestamp,
          message: message
        }
      end
    end
  end
end
