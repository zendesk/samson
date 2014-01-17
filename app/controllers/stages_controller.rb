class StagesController < ApplicationController
  before_filter :authorize_admin!, except: [:show]
  before_filter :authorize_deployer!

  before_filter :find_project
  before_filter :find_stage, only: [:show, :edit, :update, :lock, :unlock, :destroy]

  rescue_from ActiveRecord::RecordNotFound do
    if @project
      redirect_to project_path(@project)
    else
      redirect_to root_path
    end
  end

  def index
    @stages = @project.stages
  end

  def show
    @deploys = @stage.deploys.page(params[:page])
  end

  def new
    @stage = @project.stages.build(command_ids: Command.global.pluck(:id))
    @stage.flowdock_flows.build
  end

  def create
    # Need to ensure project is already associated
    @stage = @project.stages.build
    @stage.attributes = stage_params

    if @stage.save
      redirect_to project_stage_path(@project, @stage)
    else
      flash[:error] = @stage.errors.full_messages

      @stage.flowdock_flows.build
      render :new
    end
  end

  def edit
    @stage.flowdock_flows.build
  end

  def update
    if @stage.update_attributes(stage_params)
      redirect_to project_stage_path(@project, @stage)
    else
      flash[:error] = @stage.errors.full_messages

      @stage.flowdock_flows.build
      render :edit
    end
  end

  def lock
    @stage.lock!
    redirect_to project_stages_path(@project)
  end

  def unlock
    @stage.unlock!
    redirect_to project_stages_path(@project)
  end

  def destroy
    @stage.soft_delete!
    redirect_to project_path(@project)
  end

  private

  def stage_params
    params.require(:stage).permit(
      :name, :command,
      :notify_email_address,
      command_ids: [],
      flowdock_flows_attributes: [:id, :name, :token, :_destroy]
    )
  end

  def find_project
    @project = Project.find(params[:project_id])
  end

  def find_stage
    @stage = @project.stages.find(params[:id])
  end
end
