threads 8,250
preload_app!

on_restart do
  JobExecution.all.each(&:wait!)
end
