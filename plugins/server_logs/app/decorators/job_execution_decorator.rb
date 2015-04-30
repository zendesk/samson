# wait for reports from hosts to come back
JobExecution.prepend(Module.new do
  private

  def execute_commands!(commands)
    if stage.try(:wait_for_server_logs)
      KafkaListener.new(@job.deploy_id, @output).listen { super }
    else
      super
    end
  end
end)

