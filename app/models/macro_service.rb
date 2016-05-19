class MacroService
  attr_reader :project, :user

  def initialize(project, user)
    @project = project
    @user = user
  end

  def execute!(macro)
    @project.jobs.create(
      user: @user,
      command: macro.script,
      commit: macro.reference
    )
  end
end
