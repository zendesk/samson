class DashboardsController < ApplicationController
  before_action :find_environment

  def show
    @before = Time.parse(params[:before] || Time.now.to_s(:db))
  end

  def deploy_groups
    render json: { 'deploy_groups' => @environment.deploy_groups.sort_by(&:natural_order) }
  end

  private

  def find_environment
    @environment = Environment.find_by_param!(params[:id])
  end
end
