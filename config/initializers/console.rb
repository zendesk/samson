# frozen_string_literal: true
Rails.application.console do
  Rails::ConsoleMethods.send(:prepend, Samson::ConsoleExtensions)
  puts "Samson version: #{SAMSON_VERSION.first(7)}" if SAMSON_VERSION
  ActiveRecord::Base.logger = Rails.logger = ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(STDOUT))
  Rails.logger.level = :info if ENV['PROFILE']
  Audited.store[:audited_user] = "rails console #{ENV.fetch("USER")}"
end
