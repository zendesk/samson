class MacrosController < ApplicationController
  include CurrentProject
  include ProjectLevelAuthorization

  before_action :authorize_deployer!
  before_action do
    find_project(params[:project_id])
  end
  before_action :authorize_project_admin!, only: [:new, :create, :edit, :update, :destroy]
  before_action :find_macro, only: [:edit, :update, :execute, :destroy]

  def index
    @macros = @project.macros.page(params[:page])
  end

  def new
    @macro = @project.macros.build
  end

  def create
    @macro = @project.macros.build(macro_params)

    if @macro.save
      redirect_to project_macros_path(@project)
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @macro.update_attributes(macro_params)
      redirect_to project_macros_path(@project)
    else
      render :edit
    end
  end

  def execute
    macro_service = MacroService.new(@project, current_user)
    job = macro_service.execute!(@macro)

    if job.persisted?
      JobExecution.start_job(job.commit, job)
      redirect_to [@project, job]
    else
      redirect_to project_macros_path(@project)
    end
  end

  def destroy
    if @macro.user == current_user || current_user.is_super_admin?
      @macro.soft_delete!
      redirect_to project_macros_path(@project)
    else
      head :unauthorized
    end
  end

  private

  def macro_params
    params.require(:macro).permit(
      :name, :reference, :command,
      command_ids: []
    )
  end

  def command_params
    params.require(:commands).permit(ids: [])
  end

  def find_macro
    @macro = @project.macros.find(params[:id])
  end
end
