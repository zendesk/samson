class Admin::DeployGroupsController < ApplicationController
  before_action :authorize_admin!
  before_action :authorize_super_admin!, only: [ :create, :new, :update, :destroy ]
  before_action :deploy_group, only: [:edit, :update, :destroy]

  def index
    @deploy_groups = DeployGroup.all
  end

  def new
    @deploy_group = DeployGroup.new
  end

  def create
    new_deploy_group = DeployGroup.create(deploy_group_params)
    if new_deploy_group.persisted?
      redirect_to action: 'index'
    else
      flash[:error] = "Failed to create deploy group: #{new_deploy_group.errors.full_messages}"
      redirect_to action: :new
    end
  end

  def update
    if deploy_group.update_attributes(deploy_group_params)
      redirect_to action: 'index'
    else
      flash[:error] = "Failed to update deploy group: #{deploy_group.errors.full_messages}"
      redirect_to :back
    end
  end

  def destroy
    deploy_group.soft_delete!
    flash[:notice] = "Successfully deleted deploy group: #{deploy_group.name}"
    redirect_to action: 'index'
  end

  private

  def deploy_group_params
    params.require(:deploy_group).permit(:name, :environment_id)
  end

  def deploy_group
    @deploy_group ||= DeployGroup.find(params[:id])
  rescue
    flash[:error] = "Failed to find the deploy group: #{params[:id]}"
    redirect_to action: 'index'
  end
end
