require 'sucker_punch/async_syntax'
raise "Require in config/initializers/sucker_punch.rb is no longer needed" if Rails::VERSION::STRING.split('.')[0].to_i >= 5
