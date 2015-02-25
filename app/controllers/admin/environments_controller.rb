class Admin::EnvironmentsController < ApplicationController
  before_action :authorize_admin!
  before_action :authorize_super_admin!, only: [ :create, :new, :edit, :update, :destroy ]

  rescue_from ActiveRecord::RecordNotFound do |error|
    flash[:error] = "Environment not found."
    redirect_to admin_environment_path
  end

  def edit
    @environment = Environment.find(params[:id])
  end

  def index
    @environments = Environment.all
  end

  def new
    @environment = Environment.new
  end

  def create
    env = Environment.create!(env_params)
    Rails.logger.info("#{current_user.name_and_email} created the environment #{env.name}")
    redirect_to action: 'index'
  rescue => ex
    flash[:error] = "Failed to create environment: #{ex.message}"
    redirect_to :back
  end

  def update
    env = Environment.find(params[:id])
    env.update_attributes!(env_params)
    Rails.logger.info("#{current_user.name_and_email} changed the environment #{env.name}")
    redirect_to action: 'index'
  rescue => ex
    flash[:error] = "Failed to update environment: #{ex.message}"
    redirect_to :back
  end

  def destroy
    env = Environment.find(params[:id])
    env.destroy!
    flash[:notice] = "Successfully deleted environment: #{env.name}"
    redirect_to action: 'index'
  end

  private

  def env_params
    params.require(:environment).permit(:name, :is_production)
  end
end
