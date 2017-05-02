# frozen_string_literal: true
# This file is used by Rack-based servers to start the application.
ENV['SERVER_MODE'] = '1'
require_relative 'config/environment'

Thread.new do
  const = 0
  meth = 0

  loop do
    sleep 1
    stat = RubyVM.stat
    puts "DIFF #{stat[:global_constant_state] - const} / #{stat[:global_method_state] - meth}"
    const = stat[:global_constant_state]
    meth = stat[:global_method_state]
  end
end

run Rails.application
