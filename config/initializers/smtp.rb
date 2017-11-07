# frozen_string_literal: true
require 'uri'

smtp_url = URI.parse(ENV["SMTP_URL"] || "smtp://localhost")
smtp_url.port ||= 25
smtp_url.user ||= ENV["SMTP_USER"]
smtp_url.password ||= ENV["SMTP_PASSWORD"]

ActionMailer::Base.smtp_settings = {
  port:                 smtp_url.port,
  address:              smtp_url.host,
  user_name:            smtp_url.user,
  password:             smtp_url.password,
  authentication:       'plain',
  enable_starttls_auto: false,
  openssl_verify_mode:  'none'
}
