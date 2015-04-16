class Admin::DeployGroupsController < ApplicationController
  load_and_authorize_resource class: DeployGroup
  skip_authorize_resource only: :index
  skip_load_resource only: :index

  def index
    authorize! :admin_read, DeployGroup
    @deploy_groups = DeployGroup.all
  end

  def new
    render 'edit'
  end

  def create
    if @deploy_group.save
      flash[:notice] = "Successfully created deploy group: #{@deploy_group.name}"
      redirect_to action: 'index'
    else
      flash[:error] = @deploy_group.errors.full_messages
      render 'edit'
    end
  end

  def update
    if @deploy_group.update_attributes(update_params)
      flash[:notice] = "Successfully saved deploy group: #{@deploy_group.name}"
      redirect_to action: 'index'
    else
      flash[:error] = @deploy_group.errors.full_messages
      render 'edit'
    end
  end

  def destroy
    @deploy_group.soft_delete!
    flash[:notice] = "Successfully deleted deploy group: #{@deploy_group.name}"
    redirect_to action: 'index'
  end

  private

  def create_params
    params.require(:deploy_group).permit(:name, :environment_id)
  end

  def update_params
    params.require(:deploy_group).permit(:name, :environment_id, :id)
  end
end
