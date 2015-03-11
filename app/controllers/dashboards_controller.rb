class DashboardsController < ApplicationController
  def show
    @environment = Environment.find_by_name!(params[:id])
    @deploys = ordered_projects.each_with_object({}) do |project, hash|
      hash[project] = project.last_deploy_by_group
      hash[project].select! { |id, _v| @environment.deploy_group_ids.include?(id) }
    end
  end

  private

  def ordered_projects
    (current_user.starred_projects.alphabetical.with_deploy_groups + Project.alphabetical.with_deploy_groups).uniq
  end
end
