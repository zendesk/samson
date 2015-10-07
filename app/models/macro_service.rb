class MacroService
  attr_reader :project, :user

  def initialize(project, user)
    @project, @user = project, user
  end

  def execute!(macro)
    @project.jobs.create(
      user: @user,
      command: macro.macro_command,
      commit: macro.reference
    )
  end
end
