class DeployGroupsController < ApplicationController
  before_action :find_deploy_group

  def show
    respond_to do |format|
      format.html do
        @deploys = @deploy_group.deploys.page(params[:page])
      end
      format.json do
        render json: { deploys: @deploy_group.deploys.successful.page(params[:page]).as_json(include: :project, methods: :url) }
      end
    end
  end

  private

  def find_deploy_group
    @deploy_group = DeployGroup.find(params[:id])
  end
end
