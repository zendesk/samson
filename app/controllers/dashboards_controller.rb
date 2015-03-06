class DashboardsController < ApplicationController
  def show
    @environment = Environment.find(params[:id])
    @data = Project.all.inject({}) do |hash, project|
      hash[project] = project.releases_by_deploy_group
      hash[project].select! { |id, _v| DeployGroup.find(id).environment_id == @environment.id }
      hash
    end
  end
end
