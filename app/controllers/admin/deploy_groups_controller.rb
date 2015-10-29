class Admin::DeployGroupsController < ApplicationController
  before_action :authorize_admin!
  before_action :authorize_super_admin!, only: [ :create, :new, :update, :destroy ]
  before_action :deploy_group, only: [:show, :edit, :update, :destroy]

  def index
    @deploy_groups = DeployGroup.all
  end

  def new
    @deploy_group = DeployGroup.new
    Samson::Hooks.fire(:edit_deploy_group, @deploy_group)
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
    Samson::Hooks.fire(:edit_deploy_group, @deploy_group)
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
    params.require(:deploy_group).permit(*allowed_deploy_group_params)
  end

  def allowed_deploy_group_params
    ([:name, :environment_id, :env_value] + Samson::Hooks.fire(:deploy_group_permitted_params)).freeze
  end

  def deploy_group
    @deploy_group ||= DeployGroup.find(params[:id])
  end
end
