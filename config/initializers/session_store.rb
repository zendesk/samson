# Be sure to restart your server when you modify this file.

config = Samson::Application.config
options = {key: '_samson_session'}

# when using multiple domains we have to share our cookies
# this breaks session on heroku when using *.herokuapp.com
used_domains = [config.samson.deploy_origin, config.samson.stream_origin, config.samson.uri.to_s]
options[:domain] = :all if used_domains.uniq.size != 1

Samson::Application.config.session_store :cookie_store, options
