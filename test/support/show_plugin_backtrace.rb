# by default backtrace from plugins is hidden
# to update: add a error into a file inside a plugin and run the test
# backtrace should show the exact line of the error
old = Rails::BacktraceCleaner::APP_DIRS_PATTERN
Rails::BacktraceCleaner.send(:remove_const, :APP_DIRS_PATTERN)
Rails::BacktraceCleaner::APP_DIRS_PATTERN = Regexp.union(old, /^\/?plugin/)
