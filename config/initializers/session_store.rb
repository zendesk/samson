# frozen_string_literal: true
# Restart your server when you modify this file.

Samson::Application.config.session_store :cookie_store, key: Samson::Application.config.session_key
