# frozen_string_literal: true
require 'splunk_logger'

token = ENV['SPLUNK_TOKEN']
url = ENV['SPLUNK_URL']
interval = (ENV['SPLUNK_INTERVAL'].presence || 1).to_i
ssl_verify = ENV['SPLUNK_DISABLE_VERIFY_SSL'] != "1"

AUDIT_LOGGER = if token && url
  SplunkLogger::Client.new({token: token, url: url, send_interval: interval, verify_ssl: ssl_verify})
else
  nil
end
