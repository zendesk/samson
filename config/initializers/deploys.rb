JobExecution.setup

at_exit do
  Deploy.active.each do |deploy|
    deploy.stop!
  end
end
