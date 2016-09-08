# frozen_string_literal: true
class ProjectsController < ApplicationController
  include CurrentProject
  include StagePermittedParams

  skip_before_action :require_project, only: [:index, :new, :create]

  before_action :authorize_admin!, only: [:new, :create, :destroy]
  before_action :authorize_project_admin!, except: [:show, :index, :deploy_group_versions]

  helper_method :project

  alias_method :project, :current_project

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
    @project.current_user = current_user
    @project.stages.build(name: "Production")
  end

  def create
    @project = Project.new(project_params)
    @project.current_user = current_user

    if @project.save
      if Rails.application.config.samson.project_created_email
        ProjectMailer.created_email(@current_user, @project).deliver_later
      end
      redirect_to @project
      Rails.logger.info("#{@current_user.name_and_email} created a new project #{@project.to_param}")
    else
      render :new
    end
  end

  def show
    respond_to do |format|
      format.html { @stages = project.stages }
      format.json { render json: project.to_json(except: [:token, :deleted_at]) }
    end
  end

  def edit
  end

  def update
    if project.update_attributes(project_params)
      redirect_to project
    else
      render :edit
    end
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
      *[
        :name,
        :repository_url,
        :description,
        :owner,
        :permalink,
        :release_branch,
        :deploy_with_docker,
        :auto_release_docker_image,
        :include_new_deploy_groups,
        { stages_attributes: stage_permitted_params }
      ] + Samson::Hooks.fire(:project_permitted_params)
    )
  end

  def projects_for_user
    if ids = current_user.starred_project_ids.presence
      Project.where(id: ids)
    else
      Project
    end
  end

  # Overriding require_project from CurrentProject
  def require_project
    @project = (Project.find_by_param!(params[:id]) if params[:id])
  end
end
