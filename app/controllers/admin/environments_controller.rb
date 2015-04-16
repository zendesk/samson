class Admin::EnvironmentsController < ApplicationController
  load_and_authorize_resource class: Environment, find_by: :param, except: :index

  def index
    authorize! :admin_read, DeployGroup
    @environments = Environment.all
  end

  def new
    render 'edit'
  end

  def create
    if @environment.save
      flash[:notice] = "Successfully saved environment: #{@environment.name}"
      redirect_to action: 'index'
    else
      flash[:error] = @environment.errors.full_messages
      render 'edit'
    end
  end

  def update
    if @environment.update_attributes(update_params)
      flash[:notice] = "Successfully saved environment: #{@environment.name}"
      redirect_to action: 'index'
    else
      flash[:error] = @environment.errors.full_messages
      render 'edit'
    end
  end

  def destroy
    @environment.soft_delete!
    flash[:notice] = "Successfully deleted environment: #{@environment.name}"
    redirect_to action: 'index'
  end

  private

  def create_params
    params.require(:environment).permit(:name, :is_production)
  end

  def update_params
    params.require(:environment).permit(:name, :is_production, :id)
  end
end
