# frozen_string_literal: true

require 'syslog/logger'
module Samson
  class SyslogFormatter < Syslog::Logger::Formatter
    def call(severity, timestamp, _progname, message)
      message_h =
        begin
          # We support only string and hash in log.
          if message.is_a?(String) && message.start_with?('{')
            JSON.parse(message)
          elsif message.is_a?(Hash)
            message
          else
            raise JSON::ParserError
          end
        rescue JSON::ParserError
          {message: message}
        end
      {
        level: severity,
        "@timestamp": timestamp,
        application: "samson",
        host: Rails.application.config.samson.uri.host
      }.merge(message_h).to_json
    end
  end
end
