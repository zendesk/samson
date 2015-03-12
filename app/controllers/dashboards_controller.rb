class DashboardsController < ApplicationController
  def show
    @deploys = ordered_projects.each_with_object({}) do |project, hash|
      hash[project] = project.last_deploy_by_group
      hash[project].select! { |id, _v| environment.deploy_group_ids.include?(id) }
    end
  end

  private

  def ordered_projects
    Project.ordered_for_user(current_user).with_deploy_groups
  end

  def environment
    @environment ||= Environment.find_by_param!(params[:id])
  end
end
