class ProjectsController < ApplicationController
  before_filter :authorize_admin!, only: [:new, :create, :edit, :update, :destroy]
  before_filter :authorize_deployer!, only: [:show]

  def index
    @projects = Project.limit(9).includes(job_histories: :user, job_locks: nil)
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
    @project = Project.find(params[:id])
  end

  def edit
    @project = Project.find(params[:id])
  end

  def update
    @project = Project.find(params[:id])

    if @project.update_attributes(project_params)
      redirect_to root_path
    else
      flash[:error] = @project.errors.full_messages.join("<br />")
      render :edit
    end
  end

  def destroy
    Project.destroy(params[:id])

    flash[:notice] = "Project removed."
    redirect_to admin_projects_path
  end

  protected

  def project_params
    params.require(:project).permit(:name)
  end
end
