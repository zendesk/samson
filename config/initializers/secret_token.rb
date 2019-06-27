# frozen_string_literal: true
# Be sure to restart your server when you modify this file.

# Your secret key is used for:
# - Verifying the integrity of signed cookies
#   (all old signed cookies will become invalid, users need to login again)
# - Secrets quick-search
#   (Rails.cache needs to be cleared for secret value search to work again)
# - Badge tokens unless BADGE_TOKEN_BASE is used
#   (All stage badges need to be re-generated using the new token)
# - Encrypting columns, unless ATTR_ENCRYPTED_KEY is used
#   (columns will unreadable and need to be read with the old key and then written with the new key)
#
# Make sure the secret is at least 30 characters and all random,
# no regular words or you'll be exposed to dictionary attacks.
# You can use `rake secret` to generate a secure secret key.

# Make sure your secret_key_base is kept private, if you're sharing your code publicly.
Samson::Application.config.secret_key_base = ENV.fetch('SECRET_TOKEN')
