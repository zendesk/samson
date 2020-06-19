# frozen_string_literal: true
require 'clockwork'
require './config/boot'
require './config/environment'

include Clockwork

require './plugins/deploy_waitlist/lib/samson_deploy_waitlist/waitlist_monitor.rb'

handler do |job|
  puts "Running #{job}"
end

every(30.seconds, 'deploy_waitlist_monitor') { SamsonDeployWaitlist::WaitlistMonitor.check_your_head }
