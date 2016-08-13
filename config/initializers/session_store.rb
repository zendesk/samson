# frozen_string_literal: true
# Be sure to restart your server when you modify this file.

config = Samson::Application.config

# enable multiple samson instances on the same base domain (samson-staging.foo.com + samson-production.foo.com)
# need to set it everywhere in case any of the samsons uses `domain: :all`
options = {key: "_samson_session_#{Rails.env}"}

# when using multiple domains we have to share our cookies
# this breaks session on heroku when using *.herokuapp.com
used_domains = [config.samson.deploy_origin, config.samson.stream_origin, config.samson.uri.to_s]
options[:domain] = :all if used_domains.uniq.size != 1

Samson::Application.config.session_store :cookie_store, options
