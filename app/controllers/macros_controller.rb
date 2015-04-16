class MacrosController < ApplicationController
  load_resource :project, find_by: :param
  load_resource only: [ :edit, :update, :execute, :destroy ]
  authorize_resource


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
    @macro.soft_delete!
    redirect_to project_macros_path(@project)
  end

  private

  def macro_params
    params.require(:macro).permit(
      :name, :reference, :command,
      command_ids: []
    )
  end
end
