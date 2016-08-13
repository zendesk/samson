# frozen_string_literal: true
ActionMailer::Base.smtp_settings = {
  authentication:       'plain',
  enable_starttls_auto: false,
  openssl_verify_mode:  'none'
}
