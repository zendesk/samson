# frozen_string_literal: true

require 'syslog/logger'
module Samson
  class SyslogFormatter < Syslog::Logger::Formatter
    def call(severity, timestamp, _progname, message)
      message_h =
        begin
          message = message.to_json unless message.is_a?(String)
          # We support only string and hash in log.
          # JSON also parse's Integer and Arrays, we skip those.
          (parsed = JSON.parse(message)).is_a?(Hash) ? parsed : raise(JSON::ParserError)
        rescue JSON::ParserError
          {"message": message&.squish}
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
