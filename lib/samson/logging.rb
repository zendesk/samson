# frozen_string_literal: true
config = Rails.application.config

if Samson::EnvCheck.set?("RAILS_LOG_TO_STDOUT")
  # heroku and docker: dump everything to stdout
  config.logger = ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(STDOUT))
elsif Samson::EnvCheck.set?("RAILS_LOG_TO_SYSLOG")
  require 'lograge'
  require 'logstash-event'
  # log 1 message per request to syslog in json format
  config.lograge.enabled = true

  config.lograge.custom_options = ->(event) do
    # show params for every request
    unwanted_keys = %w[format action controller]
    params = event.payload[:params].reject { |key, _| unwanted_keys.include? key }
    params['commits'] = '... truncated ...' if params['commits'] # lots of metadata from github we don't need
    request = event.payload[:headers].instance_variable_get(:@req)
    {
      params: params,
      user_id: request.env['warden']&.user&.id,
      client_ip: request.remote_ip
    }
  end

  config.logger = Syslog::Logger.new('samson')
  config.action_cable.logger = Syslog::Logger.new('samson')
  config.lograge.formatter = Lograge::Formatters::Logstash.new
  config.logger.formatter = config.action_cable.logger.formatter = Samson::SyslogFormatter.new
elsif ENV["SERVER_MODE"] # regular file logger that needs rotating
  # Reopen logfile when we receive a SIGHUP for log-rotation
  # puma normally kills itself with INT if it receives a SIGHUP
  # see https://github.com/puma/puma/pull/1527 and https://github.com/puma/puma/blob/master/docs/signals.md
  # We need to use self-pipe since we cannot reopen logs in an interrupt.
  # This will break stdout_redirect feature of puma since we cannot support both
  read, write = IO.pipe
  Signal.trap(:SIGHUP) { write.puts }
  Thread.new do
    loop do
      read.gets # blocking wait for trap
      Rails.logger.info "Received SIGHUP ... reopening logs"
      # Rails.logger does not know what file it opened, so we help it https://github.com/rails/rails/issues/32211
      dev = Rails.logger.instance_variable_get(:@logdev).dev
      Rails.logger.reopen(dev.path)
    end
  end
end

# workaround for our server ... always gets SIGHUP even though it does not do file logging
if ENV["IGNORE_SIGHUP"]
  Signal.trap(:SIGHUP) {}
end
