# frozen_string_literal: true
class DeployGroupsController < ApplicationController
  before_action :authorize_super_admin!, except: [:index, :show]
  before_action :deploy_group, only: [:show, :edit, :update, :destroy]

  def index
    @deploy_groups =
      if project_id = params[:project_id]
        Project.find(project_id).stages.find(params.require(:id)).deploy_groups
      else
        DeployGroup.where(nil)
      end.sort_by(&:natural_order)

    respond_to do |format|
      format.html
      format.json do
        render_as_json(:deploy_groups, @deploy_groups, allowed_includes: Samson::Hooks.fire(:deploy_group_includes))
      end
    end
  end

  def show
    @deployed = Deploy.successful.where(stage_id: @deploy_group.pluck_stage_ids).last_deploys_for_projects
    respond_to do |format|
      format.html
      format.json do
        render json: {
          deploy_group: @deploy_group.as_json,
          deploys: @deployed.as_json,
          projects: @deployed.map(&:project).as_json
        }
      end
    end
  end

  def new
    @deploy_group = DeployGroup.new
    render :edit
  end

  def create
    @deploy_group = DeployGroup.create(deploy_group_params)
    if @deploy_group.persisted?
      flash[:notice] = "Successfully created deploy group: #{@deploy_group.name}"
      redirect_to action: :index
    else
      render :edit
    end
  end

  def edit
  end

  def update
    if deploy_group.update_attributes(deploy_group_params)
      flash[:notice] = "Successfully saved deploy group: #{deploy_group.name}"
      redirect_to action: :index
    else
      render :edit
    end
  end

  def destroy
    if deploy_group.deploy_groups_stages.empty?
      deploy_group.soft_delete!
      flash[:notice] = "Successfully deleted deploy group: #{deploy_group.name}"
      redirect_to action: :index
    else
      flash[:error] = "Deploy group is still in use."
      redirect_to deploy_group
    end
  end

  private

  def deploy_group_params
    params.require(:deploy_group).permit(*allowed_deploy_group_params)
  end

  def allowed_deploy_group_params
    (
      [:name, :environment_id, :env_value, :vault_server_id, :permalink] +
      Samson::Hooks.fire(:deploy_group_permitted_params)
    ).freeze
  end

  def deploy_group
    @deploy_group ||= DeployGroup.find_by_param!(params[:id])
  end
end
