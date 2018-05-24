# frozen_string_literal: true
# Restart your server when you modify this file.

# enable multiple samson instances on the same base domain (samson-staging.foo.com + samson-production.foo.com)
Samson::Application.config.session_store :cookie_store, key: "_samson_session_#{Rails.env}"
