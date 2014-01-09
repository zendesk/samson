ActiveSupport::Notifications.subscribe("execute_shell.pusher") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)

  Rails.logger.debug("Executed shell command in %.2fms" % event.duration)
end
