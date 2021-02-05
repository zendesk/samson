# frozen_string_literal: true

require 'syslog/logger'

class Syslog::Logger
  # called by activesupport in dev mode ... not implemented since we'd need to make the base class use @level threadsafe
  def silence
    yield
  end
end

module Samson
  class SyslogFormatter < Syslog::Logger::Formatter
    # called by activesupport / implementation copied from activesupport
    def tagged(*tags)
      tags = tags.flatten # same as in activesupport, since it gets called with [[]]
      current_tags.concat tags
      yield
    ensure
      current_tags.pop tags.size
    end

    # called by activesupport / implementation copied from activesupport
    def clear_tags!
      current_tags.clear
    end

    # called by activesupport / implementation copied from activesupport
    def current_tags
      thread_key = (@thread_key ||= "syslog_logging_tags:#{object_id}")
      Thread.current[thread_key] ||= []
    end

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
        host: Rails.application.config.samson.uri.host,
        tags: current_tags
      }.merge(message_h).to_json
    end
  end
end
