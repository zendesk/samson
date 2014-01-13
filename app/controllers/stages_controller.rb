class StagesController < ApplicationController
  before_filter :find_project
  before_filter :find_stage, only: [:show, :edit, :update, :destroy]

  def show
    @deploys = find_stage.latest_deploys
    @deploy_status_for_label = {"running" => "label-info", "succeeded" => "label-success", "failed" => "label-danger", "pending" => "label-default", "cancelling" => "label-warning", "cancelled" => "label-danger"}
  end

  def new
    @stage = @project.stages.build
  end

  def create
    @stage = @project.stages.create!(stage_params)

    redirect_to project_stage_path(@project, @stage)
  end

  def edit
  end

  def update
    @stage.update_attributes(stage_params)

    redirect_to project_stage_path(@project, @stage)
  end

  def destroy
    @stage.destroy

    redirect_to project_path(@project)
  end

  private

  def stage_params
    params.require(:stage).permit(:name, :notify_email_address, :command)
  end

  def find_project
    @project = Project.find(params[:project_id])
  end

  def find_stage
    @stage = @project.stages.find(params[:id])
  end
end
