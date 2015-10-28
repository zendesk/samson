class Admin::DeployGroupsController < ApplicationController
  before_action :authorize_admin!
  before_action :authorize_super_admin!, only: [ :create, :new, :update, :destroy ]
  before_action :deploy_group, only: [:show, :edit, :update, :destroy]

  def index
    @deploy_groups = DeployGroup.all
  end

  def new
    @deploy_group = DeployGroup.new
    @deploy_group.build_cluster_deploy_group if allow_kuber_cluster_assignment?
    render 'edit'
  end

  def create
    @deploy_group = DeployGroup.create(deploy_group_params)
    if @deploy_group.persisted?
      flash[:notice] = "Successfully created deploy group: #{@deploy_group.name}"
      redirect_to action: 'index'
    else
      flash[:error] = @deploy_group.errors.full_messages
      render 'edit'
    end
  end

  def edit
    if allow_kuber_cluster_assignment?
      @deploy_group.build_cluster_deploy_group unless @deploy_group.cluster_deploy_group
    end
  end

  def update
    if deploy_group.update_attributes(deploy_group_params)
      flash[:notice] = "Successfully saved deploy group: #{deploy_group.name}"
      redirect_to action: 'index'
    else
      flash[:error] = deploy_group.errors.full_messages
      render 'edit'
    end
  end

  def destroy
    deploy_group.soft_delete!
    flash[:notice] = "Successfully deleted deploy group: #{deploy_group.name}"
    redirect_to action: 'index'
  end

  private

  def deploy_group_params
    allowed_params = [:name, :environment_id, :env_value]
    if allow_kuber_cluster_assignment?
      allowed_params << { cluster_deploy_group_attributes: [:id, :kubernetes_cluster_id, :namespace] }
    end
    dg_params = params.require(:deploy_group).permit(*allowed_params)
    if allow_kuber_cluster_assignment?
      if dg_params[:cluster_deploy_group_attributes] && dg_params[:cluster_deploy_group_attributes][:kubernetes_cluster_id].blank?
        dg_params[:cluster_deploy_group_attributes]['_destroy'] = '1'
      end
    end
    dg_params
  end

  def deploy_group
    @deploy_group ||= DeployGroup.find(params[:id])
  end

  def build_kuber_cluster
    @deploy_group.build_cluster_deploy_group unless @deploy_group.cluster_deploy_group
  end

  def allow_kuber_cluster_assignment?
    Samson::Hooks.active_plugin?('kubernetes')
  end
end
