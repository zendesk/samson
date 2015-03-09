class ProjectsController < ApplicationController
  before_action :authorize_admin!, except: [:show, :index]
  before_action :redirect_viewers!, only: [:show]
  before_action :project, only: [:show, :edit, :update]

  helper_method :project

  def index
    respond_to do |format|
      format.html do
        @projects = projects_for_user.alphabetical.includes(stages: { lock: :user })
      end

      format.json do
        render json: Project.all
      end
    end
  end

  def new
    @project = Project.new
    stage = @project.stages.build(name: "Production")
    stage.new_relic_applications.build
  end

  def create
    @project = Project.new(project_params)

    if @project.save
      if ENV['PROJECT_CREATED_NOTIFY_ADDRESS']
        ProjectMailer.created_email(@current_user,@project).deliver_later
      end
      redirect_to project_path(@project)
      Rails.logger.info("#{@current_user.name_and_email} created a new project #{@project.to_param}")
    else
      flash[:error] = @project.errors.full_messages
      render :new
    end
  end

  def show
    @stages = project.stages.includes(:lock)
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
      :description,
      :owner,
      :permalink,
      :release_branch,
      stages_attributes: [
        :name, :confirm, :command,
        :production,
        :deploy_on_release,
        :notify_email_address,
        :datadog_tags,
        :update_github_pull_requests,
        :use_github_deployment_api,
        command_ids: [],
      ] + Samson::Hooks.fire(:stage_permitted_params)
    )
  end

  def project
    @project ||= Project.find_by_param!(params[:id])
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
