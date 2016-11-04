# frozen_string_literal: true
require 'splunk_logger'

token = ENV['SPLUNK_TOKEN']
url = ENV['SPLUNK_URL']
interval = ENV['SPLUNK_INTERVAL'].to_i || 1
ssl_verify = ENV['SPLUNK_DISABLE_VERIFY_SSL'] != "1"

if (token && url)
  AUDIT_LOGGER = SplunkLogger::Client.new({token: token, url: url, send_interval: interval, verify_ssl: ssl_verify})
else
  AUDIT_LOGGER = nil
end
