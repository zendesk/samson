# frozen_string_literal: true
class Admin::EnvironmentsController < ApplicationController
  before_action :authorize_super_admin!, except: [:index]
  before_action :environment, only: [:show, :update, :destroy]

  def index
    respond_to do |format|
      format.html
      format.json { render json: Environment.all }
    end
  end

  def new
    @environment = Environment.new
    render 'show'
  end

  def show
  end

  def create
    @environment = Environment.create(env_params)
    if @environment.persisted?
      flash[:notice] = "Successfully saved environment: #{@environment.name}"
      redirect_to action: 'index'
    else
      render 'show'
    end
  end

  def update
    if environment.update_attributes(env_params)
      flash[:notice] = "Successfully saved environment: #{environment.name}"
      redirect_to action: 'index'
    else
      render 'show'
    end
  end

  def destroy
    environment.soft_delete!
    flash[:notice] = "Successfully deleted environment: #{environment.name}"
    redirect_to action: 'index'
  end

  private

  def env_params
    params.require(:environment).permit(:name, :permalink, :production)
  end

  def environment
    @environment ||= Environment.find_by_param!(params[:id])
  end
end
