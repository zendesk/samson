class ProjectsController < ApplicationController
  before_filter :authorize_admin!, only: [:new, :create, :edit, :update, :destroy]
  before_filter :authorize_deployer!, only: [:show]

  helper_method :project

  rescue_from ActiveRecord::RecordNotFound do
    flash[:error] = "Project not found."
    redirect_to root_path
  end

  def index
    @projects = Project.limit(9).where(deleted_at: nil)
  end

  def new
    @project = Project.new
  end

  def create
    @project = Project.create(project_params)

    if @project.persisted?
      redirect_to root_path
    else
      flash[:error] = @project.errors.full_messages.join("<br />")
      render :new
    end
  end

  def show
  end

  def edit
  end

  def update
    if project.update_attributes(project_params)
      redirect_to root_path
    else
      flash[:error] = project.errors.full_messages.join("<br />")
      render :edit
    end
  end

  def destroy
    project.soft_delete!

    flash[:notice] = "Project removed."
    redirect_to admin_projects_path
  end

  protected

  def project_params
    params.require(:project).permit(:name)
  end

  def project
    @project ||= Project.where(deleted_at: nil).find(params[:id])
  end
end
