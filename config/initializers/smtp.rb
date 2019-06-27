# frozen_string_literal: true
require 'uri'

smtp_url = URI.parse(ENV["SMTP_URL"] || "smtp://localhost")
port = smtp_url.port || 25
user = smtp_url.user || ENV["SMTP_USER"]
password = smtp_url.password || ENV["SMTP_PASSWORD"]
enable_starttls_auto = ENV["SMTP_ENABLE_STARTTLS_AUTO"] || false

ActionMailer::Base.smtp_settings = {
  address:              smtp_url.host,
  port:                 port,
  user_name:            user,
  password:             password,
  authentication:       'plain',
  enable_starttls_auto: enable_starttls_auto,
  openssl_verify_mode:  'none'
}
