# frozen_string_literal: true
# Log github request timing so it is more obvious what we spent our time on
# and any other backend that uses faraday
require 'faraday'

Faraday::Connection.prepend(Module.new do
  def run_request(method, url, *)
    ActiveSupport::Notifications.instrument("request.faraday.samson", method: method, url: url) { super }
  end
end)
