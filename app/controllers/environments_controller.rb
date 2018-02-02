# frozen_string_literal: true
class EnvironmentsController < ApplicationController
  before_action :authorize_resource!
  before_action :environment, only: [:show, :update, :destroy]

  def index
    respond_to do |format|
      format.html
      format.json { render_as_json :environments, Environment.all, allowed_includes: [:deploy_groups] }
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
    environment.soft_delete!(validate: false)
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
