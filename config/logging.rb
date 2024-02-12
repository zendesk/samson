# frozen_string_literal: true

config = Rails.application.config

if Samson::EnvCheck.set?("RAILS_LOG_TO_STDOUT")
  # good for heroku or docker
  config.logger = ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new($stdout))
elsif Samson::EnvCheck.set?("RAILS_LOG_TO_SYSLOG")
  require_relative "../lib/samson/syslog_formatter"
  config.logger = ActiveSupport::TaggedLogging.new(Syslog::Logger.new('samson'))
  config.logger.formatter = Samson::SyslogFormatter.new
elsif ENV["SERVER_MODE"]
  # good for development or servers without syslog
  # regular file logger that needs rotating
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

# TODO: log user id too ... doing in current_user does not work because request logs after that is done
config.log_tags = [
  ->(request) { "id:#{request.request_id}" },
  ->(request) { "ip:#{request.remote_ip}" }
]

# log 1 message per request to in json/syslog format
if ENV["RAILS_LOG_WITH_LOGRAGE"]
  require 'lograge'
  require 'logstash-event'
  config.lograge.enabled = true
  config.lograge.custom_options = ->(event) do
    # show params for every request
    unwanted_keys = ['format', 'action', 'controller']
    params = event.payload[:params].reject { |key, _| unwanted_keys.include? key }
    params['commits'] = '... truncated ...' if params['commits'] # lots of metadata from github we don't need
    request = event.payload[:headers].instance_variable_get(:@req)
    {
      params: params,
      user_id: request.env['warden']&.user&.id
    }
  end
  config.lograge.formatter = Lograge::Formatters::Logstash.new
end

# workaround for our server ... always gets SIGHUP even though it does not do file logging
Signal.trap(:SIGHUP) {} if ENV["IGNORE_SIGHUP"]

# We saw initializers hanging boot so we are logging before every initializer is called to easily debug
# Test: boot up rails and look at the logs
if ENV['SERVER_MODE'] && !Rails.env.development?
  Rails::Engine.prepend(
    Module.new do
      def load(file, *)
        Rails.logger.info "Loading initializer #{file.sub("#{Bundler.root}/", "")}"
        super
      end
    end
  )
end
