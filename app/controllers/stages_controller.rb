class StagesController < ApplicationController
  before_filter :find_project
  before_filter :find_stage

  def show
  end

  def edit
  end

  def update
    @stage.update_attributes(stage_params)

    redirect_to project_stage_path(@project, @stage)
  end

  private

  def stage_params
    params.require(:stage).permit(:name, :command)
  end

  def find_project
    @project = Project.find(params[:project_id])
  end

  def find_stage
    @stage = @project.stages.find(params[:id])
  end
end
