class ProjectsController < ApplicationController
  before_filter :authorize_admin!, except: [:show, :index]
  before_filter :redirect_viewers!, only: [:show]

  helper_method :project

  rescue_from ActiveRecord::RecordNotFound do
    flash[:error] = "Project not found."
    redirect_to root_path
  end

  def index
    respond_to do |format|
      format.html do
        @projects = projects_for_user.alphabetical.includes(stages: [:current_deploy, { lock: :user }])
      end

      format.json do
        render json: Project.all
      end
    end
  end

  def new
    @project = Project.new

    stage = @project.stages.build(name: "Production")
    stage.flowdock_flows.build
    stage.new_relic_applications.build
  end

  def create
    @project = Project.new(project_params)

    if @project.save
      redirect_to project_path(@project)
      Rails.logger.info("#{@current_user.name_and_email} created a new project #{@project.to_param}")
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
  end

  def edit
  end

  def update
    if project.update_attributes(project_params)
      redirect_to project_path(project)
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
      :release_branch,
      :versioning_schema,
      :version_bump_component,
      stages_attributes: [
        :name, :confirm, :command,
        :deploy_on_release,
        :notify_email_address,
        :datadog_tags,
        :update_github_pull_requests,
        command_ids: [],
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

  def projects_for_user
    if current_user.starred_projects.any?
      current_user.starred_projects
    else
      Project
    end
  end
end
