class JobService
  attr_reader :project, :user

  def initialize(project, user)
    @project = project
    @user = user
  end

  def execute!(reference, command_ids, command = nil)
    job_command = command_ids.map do |command_id|
      Command.find(command_id).command
    end

    job_command << command if command

    @project.jobs.create(
      user: @user,
      command: job_command.join("\n"),
      commit: reference
    )
  end
end
