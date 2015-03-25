class DashboardsController < ApplicationController
  before_action :find_environment

  def show
    @before = Time.parse(params[:before] || Time.now.to_s(:db))
  end

  def deploy_groups
    render json: { 'deploy_groups' => @environment.deploy_groups }
  end

  private

  def ordered_projects
    Project.ordered_for_user(current_user).with_deploy_groups
  end

  def find_environment
    @environment = Environment.find_by_param!(params[:id])
  end
end
