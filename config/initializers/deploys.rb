JobExecution.setup

at_exit do
  JobExecution.all.each do |job_execution|
    job_execution.stop
  end
end
