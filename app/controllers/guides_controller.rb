class GuidesController < ApplicationController
  before_action :authorize_admin!, except: [:show]

  helper_method :project
  helper_method :guide

  def create
    @guide = Guide.new(guide_params.merge({
      project_id: project.id
    }))

    if guide.save
      redirect_to project_guide_path(project)
    else
      flash[:error] = guide.errors.full_messages
      render :new
    end
  end

  def update
    if guide.update_attributes(guide_params)
      redirect_to project_guide_path(project)
    else
      flash[:error] = guide.errors.full_messages
      render :edit
    end
  end

  protected

  def guide_params
    params.require(:guide).permit(:body)
  end

  def guide
    @guide ||= project.guide || Guide.new(project_id: project.id)
  end

  def project
    @project ||= Project.find_by_param!(params[:project_id])
  end
end
