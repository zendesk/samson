class DeployGroupsController < ApplicationController
  def show
    @deploy_group = DeployGroup.find(params[:id])
    @deploys = @deploy_group.deploys.page(params[:page])
  end
end
