if Rails.env.production?
  require 'syslog/logger'
  Rails.logger = Syslog::Logger.new('samson')
end
