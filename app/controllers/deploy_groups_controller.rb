class DeployGroupsController < ApplicationController
  before_action :find_deploy_group

  def show
    respond_to do |format|
      format.html do
        @deploys = @deploy_group.deploys.page(params[:page])
      end
      format.json do
        deploys = @deploy_group.deploys.successful.limit(300).each_with_object([]) do |deploy, array|
          array << deploy.as_json.merge(
            project: deploy.project.as_json,
            url: project_deploy_path(deploy.project, deploy))
        end
        render json: { deploys: deploys }
      end
    end
  end

  private

  def find_deploy_group
    @deploy_group = DeployGroup.find(params[:id])
  end
end
