class LocksController < ApplicationController
  before_filter :authorize_deployer!

  rescue_from ActiveRecord::RecordNotFound do
    if Project.exists?(params[:project_id])
      redirect_to project_path(project)
    else
      redirect_to root_path
    end
  end

  def create
    stage.create_lock(user: current_user, description: params[:description])
    redirect_to project_stage_path(project, stage)
  end

  def destroy
    stage.lock.try(:soft_delete)
    redirect_to project_stage_path(project, stage)
  end

  protected

  def project
    @project ||= Project.find(params[:project_id])
  end

  def stage
    @stage ||= project.stages.find(params[:stage_id])
  end
end
