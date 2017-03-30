# frozen_string_literal: true
config = Rails.application.config

if Samson::EnvCheck.set?("RAILS_LOG_TO_STDOUT")
  # heroku and docker: dump everything to stdout
  config.logger = ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(STDOUT))
elsif Samson::EnvCheck.set?("RAILS_LOG_TO_SYSLOG")
  # log 1 message per request to syslog in json format
  config.lograge.enabled = true

  config.lograge.custom_options = lambda do |event|
    # show params for every request
    unwanted_keys = %w[format action controller]
    params = event.payload[:params].reject { |key, _| unwanted_keys.include? key }
    params['commits'] = '... truncated ...' if params['commits'] # lots of metadata from github we don't need
    request = event.payload[:headers].instance_variable_get(:@req)
    {
      params: params,
      user_id: request.env['warden']&.user&.id,
      ip: request.remote_ip
    }
  end

  require 'syslog/logger'
  config.logger = Syslog::Logger.new('samson')
  config.lograge.formatter = Lograge::Formatters::Logstash.new
end
