class ProjectsController < ApplicationController
  before_filter :authorize_admin!, except: [:show, :index]
  before_filter :redirect_viewers!, only: [:show]

  helper_method :project

  rescue_from ActiveRecord::RecordNotFound do
    flash[:error] = "Project not found."
    redirect_to root_path
  end

  def index
    @projects = Project.includes(stages: [:current_deploy, :last_deploy, :lock])
  end

  def new
    @project = Project.new

    stage = @project.stages.build(name: "Production")
    stage.flowdock_flows.build
  end

  def create
    @project = Project.new(project_params)

    if @project.save
      redirect_to root_path
    else
      stage = @project.stages.last
      stage ||= @project.stages.build
      stage.flowdock_flows.build if stage.flowdock_flows.empty?

      flash[:error] = @project.errors.full_messages
      render :new
    end
  end

  def show
    @stages = project.stages.includes(:last_deploy, :lock)
    @deploys = project.deploys.page(params[:page])
  end

  def edit
  end

  def releases
    @releases = ReleaseList.latest_releases_for(project.github_repo)

    render json: @releases
  end

  def update
    if project.update_attributes(project_params)
      redirect_to root_path
    else
      flash[:error] = project.errors.full_messages
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
    params.require(:project).permit(
      :name,
      :repository_url,
      stages_attributes: [
        :name, :confirm, :command,
        :notify_email_address,
        :command_ids => [],
        flowdock_flows_attributes: [:name, :token]
      ]
    )
  end

  def project
    @project ||= Project.find(params[:id])
  end

  def redirect_viewers!
    unless current_user.is_deployer?
      redirect_to project_deploys_path(project)
    end
  end
end
