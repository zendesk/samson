class DashboardsController < ApplicationController
  load_resource :environment, find_by: :param, id_param: :id

  def show
    @before = Time.parse(params[:before] || Time.now.to_s(:db))
  end

  def deploy_groups
    render json: { 'deploy_groups' => @environment.deploy_groups }
  end
end
