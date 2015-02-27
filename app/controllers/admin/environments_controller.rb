class Admin::EnvironmentsController < ApplicationController
  before_action :authorize_admin!
  before_action :authorize_super_admin!, only: [ :create, :new, :edit, :update, :destroy ]
  before_action :environment, only: [:edit, :update, :destroy]

  def index
    @environments = Environment.all
  end

  def new
    @environment = Environment.new
  end

  def create
    new_env = Environment.create(env_params)
    if new_env.persisted?
      redirect_to action: 'index'
    else
      flash[:error] = "Failed to create environment: #{new_env.errors.full_messages}"
      redirect_to action: :new
    end
  end

  def update
    if environment.update_attributes(env_params)
      redirect_to action: 'index'
    else
      flash[:error] = "Failed to update environment: #{environment.errors.full_messages}"
      redirect_to :back
    end
  end

  def destroy
    environment.soft_delete!
    flash[:notice] = "Successfully deleted environment: #{environment.name}"
    redirect_to action: 'index'
  end

  private

  def env_params
    params.require(:environment).permit(:name, :is_production)
  end

  def environment
    @environment ||= Environment.find(params[:id])
  rescue
    flash[:error] = "Failed to find the environment: #{params[:id]}"
    redirect_to action: 'index'
  end
end
