# frozen_string_literal: true
require 'splunk_logger'

token = ENV['SPLUNK_TOKEN']
url = ENV['SPLUNK_URL']
interval = Integer(ENV['SPLUNK_INTERVAL'] || 1) # defaults to dumping queue every second or when 100 messages are queued
ssl_verify = ENV['SPLUNK_DISABLE_VERIFY_SSL'] != '1' # enable to check if cert is bad

if ENV['AUDIT_PLUGIN'] == '1' && token && url
  AUDIT_LOG_CLIENT = SplunkLogger::Client.new(
    token: token,
    url: url,
    send_interval: interval,
    verify_ssl: ssl_verify
  )
else
  AUDIT_LOG_CLIENT = nil
end
