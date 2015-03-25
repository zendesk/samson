class DeployGroupsController < ApplicationController
  def show
    @deploy_group = DeployGroup.find(params[:id])
    @deploys = @deploy_group.deploys.page(params[:page])
  end

  def deploys
    deploys = DeployGroup.find(params[:id]).stages.each_with_object([]) do |stage, array|
      stage.deploys.each do |deploy|
        array << deploy.as_json.merge(project: deploy.project.as_json,
                                      url: project_deploy_path(deploy.project, deploy))
      end
    end
    render json: { deploys: deploys }
  end
end
