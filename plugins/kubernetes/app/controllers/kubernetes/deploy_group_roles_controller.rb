# frozen_string_literal: true
class Kubernetes::DeployGroupRolesController < ApplicationController
  before_action :find_role, only: [:show, :edit, :update, :destroy]
  before_action :find_stage, only: [:seed]
  before_action :authorize_project_admin!, except: [:index, :show, :new]

  DEFAULT_BRANCH = "master"

  def new
    attributes = (params[:kubernetes_deploy_group_role] ? deploy_group_role_params : {})
    @deploy_group_role = ::Kubernetes::DeployGroupRole.new(attributes)
  end

  def create
    @deploy_group_role = ::Kubernetes::DeployGroupRole.new(deploy_group_role_params)
    if @deploy_group_role.save
      redirect_back fallback_location: @deploy_group_role
    else
      render :new, status: 422
    end
  end

  def index
    @deploy_group_roles = ::Kubernetes::DeployGroupRole
    [:project_id, :deploy_group_id].each do |scope|
      if id = params.dig(:search, scope).presence
        @deploy_group_roles = @deploy_group_roles.where(scope => id)
      end
    end
    @deploy_group_roles = @deploy_group_roles.
      joins(:project, :kubernetes_role).
      order('projects.name, kubernetes_roles.name')

    respond_to do |format|
      format.html
      format.json { render json: {deploy_group_roles: @deploy_group_roles} }
    end
  end

  def show
    respond_to do |format|
      format.html
      format.json do
        deploy_group_role = @deploy_group_role.as_json
        if params[:include].present? && params[:include].to_s.split(',').include?("template")

          release = Kubernetes::Release.create(
            git_sha: params['git_sha'] || DEFAULT_BRANCH,
            git_ref: params['git_ref'] || DEFAULT_BRANCH,
            project: Project.find_by_id(@deploy_group_role.project_id),
            user: current_user,
            deploy_groups: [DeployGroup.find_by_id(@deploy_group_role.deploy_group)]
          )
          release_doc = Kubernetes::ReleaseDoc.new(
            kubernetes_release: release,
            kubernetes_role: Kubernetes::Role.find_by_id(@deploy_group_role.kubernetes_role_id),
            deploy_group: DeployGroup.find_by_id(@deploy_group_role.deploy_group)
          )
          deploy_group_role[:template] = release_doc.send(:verification_template)
        end

        render json: {
          deploy_group_role: deploy_group_role
        }
      end
    end
  end

  def edit
  end

  def update
    @deploy_group_role.assign_attributes(
      deploy_group_role_params.except(:project_id, :deploy_group_id, :kubernetes_role_id)
    )
    if @deploy_group_role.save
      redirect_back fallback_location: @deploy_group_role
    else
      render :edit, status: 422
    end
  end

  def destroy
    @deploy_group_role.destroy
    redirect_to action: :index
  end

  def seed
    created = ::Kubernetes::DeployGroupRole.seed!(@stage)
    options =
      if created.all?(&:persisted?)
        {notice: "Missing roles seeded."}
      else
        errors = ["Roles failed to seed, fill them in manually."]
        errors.concat(created.map do |dgr|
          "#{dgr.kubernetes_role.name} for #{dgr.deploy_group.name}: #{dgr.errors.full_messages.to_sentence}"
        end)
        {alert: view_context.simple_format(errors.join("\n"))}
      end
    redirect_to [@stage.project, @stage], options
  end

  private

  def current_project
    if action_name == 'create'
      Project.find(deploy_group_role_params.require(:project_id))
    elsif action_name == 'seed'
      @stage.project
    else
      @deploy_group_role.project
    end
  end

  def find_role
    @deploy_group_role = ::Kubernetes::DeployGroupRole.find(params.require(:id))
  end

  def find_stage
    @stage = Stage.find(params.require(:stage_id))
  end

  def deploy_group_role_params
    params.require(:kubernetes_deploy_group_role).permit(
      :kubernetes_role_id, :requests_memory, :requests_cpu, :limits_memory, :limits_cpu,
      :replicas, :project_id, :deploy_group_id
    )
  end
end
