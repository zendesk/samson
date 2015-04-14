class ProjectsController < ApplicationController
  include StagePermittedParams

  before_action :authorize_admin!, except: [:show, :index, :deploy_group_versions]
  before_action :redirect_viewers!, only: [:show]
  before_action :project, only: [:show, :edit, :update, :deploy_group_versions]
  before_action :get_environments, only: [:new, :create]

  helper_method :project

  def index
    respond_to do |format|
      format.html do
        @projects = projects_for_user.alphabetical
      end

      format.json do
        render json: Project.ordered_for_user(current_user).all
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
      redirect_to @project
      Rails.logger.info("#{@current_user.name_and_email} created a new project #{@project.to_param}")
    else
      flash[:error] = @project.errors.full_messages
      render :new
    end
  end

  def show
    @stages = project.stages
  end

  def edit
  end

  def update
    if project.update_attributes(project_params)
      redirect_to project
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

  def deploy_group_versions
    before = params[:before] ? Time.parse(params[:before]) : Time.now
    deploy_group_versions = project.last_deploy_by_group(before).each_with_object({}) do |(id, deploy), hash|
      hash[id] = deploy.as_json(methods: :url)
    end
    render json: deploy_group_versions
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
      stages_attributes: stage_permitted_params
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

  def get_environments
    @environments = Environment.all
  end
end
