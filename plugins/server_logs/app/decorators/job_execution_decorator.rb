# wait for reports from hosts to come back
JobExecution.prepend(Module.new do
  private

  def execute_commands!(commands)
    if stage.try(:wait_for_server_logs)
      deply_id = @job.project.github_repo.split("/").last # TODO pass a real id to meatballs
      KafkaListener.new(deply_id, @output).listen { super }
    else
      super
    end
  end
end)

