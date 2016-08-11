# frozen_string_literal: true
# by default backtrace from plugins are hidden in test output and production logs
# to update: add a error into a file inside a plugin and run the test
# backtrace should show the exact line of the error
require 'rails/backtrace_cleaner'
old = Rails::BacktraceCleaner::APP_DIRS_PATTERN
Rails::BacktraceCleaner.send(:remove_const, :APP_DIRS_PATTERN)
Rails::BacktraceCleaner::APP_DIRS_PATTERN = Regexp.union(old, %r{^/?plugin})
