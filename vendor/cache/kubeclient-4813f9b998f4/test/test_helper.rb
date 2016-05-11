require 'minitest/autorun'
require 'webmock/minitest'
require 'json'
require 'kubeclient'

# Assumes test files will be in a subdirectory with the same name as the
# file suffix.  e.g. a file named foo.json would be a "json" subdirectory.
def open_test_file(name)
  File.new(File.join(File.dirname(__FILE__), name.split('.').last, name))
end
