# frozen_string_literal: true

require 'syslog/logger'

module Samson
  class SyslogFormatter < Syslog::Logger::Formatter
    def call(severity, timestamp, _progname, message)
      message_h =
        if message.is_a?(String) && message.start_with?('{')
          begin
            JSON.parse(message)
          rescue JSON::ParserError
            {message: message}
          end
        elsif message.is_a?(Hash)
          message
        else
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
