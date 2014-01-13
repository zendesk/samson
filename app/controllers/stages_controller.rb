class StagesController < ApplicationController
  before_filter :authorize_admin!, except: [:show]

  before_filter :find_project
  before_filter :find_stage, only: [:show, :edit, :update, :destroy]

  rescue_from ActiveRecord::RecordNotFound do
    if @project
      redirect_to project_path(@project)
    else
      redirect_to root_path
    end
  end

  def show
  end

  def new
    @stage = @project.stages.build
  end

  def create
    @stage = @project.stages.create(stage_params) do |stage|
      stage.stage_commands.build(command: command) if command
    end

    if @stage.persisted?
      redirect_to project_stage_path(@project, @stage)
    else
      flash[:error] = 'Stage failed.'
      render :new
    end
  end

  def edit
  end

  def update
    @stage.stage_commands.build(command: command) if command

    if @stage.update_attributes(stage_params)
      redirect_to project_stage_path(@project, @stage)
    else
      flash[:error] = 'Stage failed.'
      render :edit
    end
  end

  def destroy
    @stage.destroy
    redirect_to project_path(@project)
  end

  private

  def stage_params
    params.require(:stage).permit(
      :name,
      :notify_email_address,
      command_ids: [],
      flowdock_flows_attributes: [:id, :name, :token]
    )
  end

  def command_param
    params.require(:stage).permit(:command)
  end

  def find_project
    @project = Project.find(params[:project_id])
  end

  def find_stage
    @stage = @project.stages.find(params[:id])
  end

  def command
    @command ||= if command_param[:command].present?
      Command.new(command: command_param[:command], user: current_user)
    end
  end
end
