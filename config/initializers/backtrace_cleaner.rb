# frozen_string_literal: true
require 'rails/backtrace_cleaner'

# by default backtrace from plugins are hidden in test output and production logs
# to update: add a error into a file inside a plugin and run the test
# backtrace should show the exact line of the error
old = Rails::BacktraceCleaner::APP_DIRS_PATTERN
Rails::BacktraceCleaner.send(:remove_const, :APP_DIRS_PATTERN)
Rails::BacktraceCleaner::APP_DIRS_PATTERN = Regexp.union(old, %r{^/?plugin})

# hide mapped_database_exceptions which wraps all AR calls but mostly does nothing
Rails.backtrace_cleaner.add_silencer { |line| line.include?("lib/samson/mapped_database_exceptions.rb") }

# hide test-support which lots of tests go through, especially needed for test/support/query_counter.rb
# which shows query origin
Rails.backtrace_cleaner.add_silencer { |line| line.include?("test/support/") }
