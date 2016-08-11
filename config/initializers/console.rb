# frozen_string_literal: true
Rails.application.console do
  Rails::ConsoleMethods.send(:prepend, Samson::ConsoleExtensions)
  puts "Samson version: #{Rails.application.config.samson.revision.to_s.first(7)}"
end
