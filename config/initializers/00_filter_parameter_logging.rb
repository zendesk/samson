# frozen_string_literal: true
# Configure sensitive parameters which will be filtered from the log file
# Used in airbrake.rb but does not support the 'foo.bar' syntax as rails does
# https://github.com/airbrake/airbrake-ruby/issues/137
Rails.application.config.filter_parameters.concat [:password, :value]
