class Admin::EnvironmentsController < ApplicationController
  before_action :authorize_admin!, except: [:index]
  before_action :authorize_super_admin!, only: [:create, :new, :edit, :update, :destroy]
  before_action :environment, only: [:edit, :update, :destroy]

  def index
    respond_to do |format|
      format.html
      format.json { render json: Environment.all }
    end
  end

  def new
    @environment = Environment.new
    render 'edit'
  end

  def create
    @environment = Environment.create(env_params)
    if @environment.persisted?
      flash[:notice] = "Successfully saved environment: #{@environment.name}"
      redirect_to action: 'index'
    else
      render 'edit'
    end
  end

  def update
    if environment.update_attributes(env_params)
      flash[:notice] = "Successfully saved environment: #{environment.name}"
      redirect_to action: 'index'
    else
      render 'edit'
    end
  end

  def destroy
    environment.soft_delete!
    flash[:notice] = "Successfully deleted environment: #{environment.name}"
    redirect_to action: 'index'
  end

  private

  def env_params
    params.require(:environment).permit(:name, :production)
  end

  def environment
    @environment ||= Environment.find_by_param!(params[:id])
  end
end
