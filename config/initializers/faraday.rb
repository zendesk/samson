# frozen_string_literal: true
# Log github request timing so it is more obvious what we spent our time on
# and any other backend that uses faraday
require 'faraday'

Faraday::Connection.prepend(
  Module.new do
    def run_request(method, url, *args)
      raise "Missing url for logging, do not use `do |request| request.url = ` pattern" unless url
      log_url = url.gsub(/key=\w+/, "key=redacted") # ignore datadog credentials and maybe others
      ActiveSupport::Notifications.instrument("request.faraday.samson", method: method, url: log_url) { super }
    end
  end
)
