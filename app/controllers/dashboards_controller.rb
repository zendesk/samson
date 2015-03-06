class DashboardsController < ApplicationController
  def show
    @environment = Environment.find(params[:id])
    @data = Project.alphabetical.each_with_object({}) do |project, hash|
      hash[project] = project.last_release_by_deploy_group
      hash[project].select! { |id, _v| @environment.deploy_group_ids.include?(id) }
    end
  end
end
