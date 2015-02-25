class Admin::DeployGroupsController < ApplicationController
  before_action :authorize_admin!
  before_action :authorize_super_admin!, only: [ :create, :new, :update, :destroy ]

  rescue_from ActiveRecord::RecordNotFound do |error|
    flash[:error] = "Deploy Group not found."
    redirect_to admin_deploy_group_path
  end

  def edit
    @deploy_group = DeployGroup.find(params[:id])
  end

  def index
    @deploy_groups = DeployGroup.all
  end

  def new
    @deploy_group = DeployGroup.new
  end

  def create
    deploy_group = DeployGroup.create!(deploy_group_params)
    Rails.logger.info("#{current_user.name_and_email} created the DeployGroup #{deploy_group.name}")
    redirect_to action: 'index'
  rescue => ex
    flash[:error] = "Failed to create DeployGroup: #{ex.message}"
    redirect_to :back
  end

  def update
    deploy_group = DeployGroup.find(params[:id])
    deploy_group.update_attributes!(deploy_group_params)
    Rails.logger.info("#{current_user.name_and_email} changed the DeployGroup #{deploy_group.name}")
    redirect_to action: 'index'
  rescue => ex
    flash[:error] = "Failed to update DeployGroup: #{ex.message}"
    redirect_to :back
  end

  def destroy
    deploy_group = DeployGroup.find(params[:id])
    deploy_group.destroy!
    flash[:notice] = "Successfully deleted DeployGroup: #{deploy_group.name}"
    redirect_to action: 'index'
  end

  private

  def deploy_group_params
    params.require(:deploy_group).permit(:name, :environment_id)
  end
end
