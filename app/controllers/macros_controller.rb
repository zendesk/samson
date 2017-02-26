# frozen_string_literal: true
class MacrosController < ApplicationController
  include CurrentProject

  before_action :authorize_project_deployer!
  before_action :authorize_project_admin!, except: [:index, :execute]
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
    job = @project.jobs.build(
      user: current_user,
      command: @macro.script,
      commit: @macro.reference
    )

    if job.save
      JobExecution.start_job(JobExecution.new(job.commit, job))
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

  def find_macro
    @macro = @project.macros.find(params[:id])
  end
end
