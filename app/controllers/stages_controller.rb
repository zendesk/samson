class StagesController < ApplicationController
  before_filter :authorize_admin!, except: [:index, :show]
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

    respond_to do |format|
      format.html
      format.json do
        render json: @stages
      end
    end
  end

  def show
    @deploys = @stage.deploys.includes(:stage, job: :user).page(params[:page])
  end

  def new
    @stage = @project.stages.build(command_ids: Command.global.pluck(:id))
    @stage.flowdock_flows.build
    @stage.new_relic_applications.build
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
      @stage.new_relic_applications.build

      render :new
    end
  end

  def edit
    @stage.flowdock_flows.build
    @stage.new_relic_applications.build
  end

  def update
    if @stage.update_attributes(stage_params)
      redirect_to project_stage_path(@project, @stage)
    else
      flash[:error] = @stage.errors.full_messages

      @stage.flowdock_flows.build
      @stage.new_relic_applications.build

      render :edit
    end
  end

  def destroy
    @stage.soft_delete!
    redirect_to project_path(@project)
  end

  def reorder
    Stage.reorder(params[:stage_id])

    head :ok
  end

  private

  def stage_params
    params.require(:stage).permit(
      :name, :command, :confirm,
      :notify_email_address,
      :datadog_tags,
      :update_pr,
      command_ids: [],
      flowdock_flows_attributes: [:id, :name, :token, :_destroy],
      new_relic_applications_attributes: [:id, :name, :_destroy]
    )
  end

  def find_project
    @project = Project.find(params[:project_id])
  end

  def find_stage
    @stage = @project.stages.find(params[:id])
  end
end
