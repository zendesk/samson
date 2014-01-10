threads 8,250
preload_app!

bind 'tcp://0.0.0.0:9080'

on_restart do
  JobExecution.all.each(&:wait!)
end
