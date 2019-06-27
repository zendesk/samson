# frozen_string_literal: true
class DashboardsController < ApplicationController
  before_action :find_environment

  def show
    @before = Time.parse(params[:before] || Time.now.to_s(:db))
    @deploy_groups = @environment.deploy_groups
    @projects = Project.all
    @failed_deploys = (params[:failed_deploys] == "true")
    @versions = project_versions(@before)
  end

  def deploy_groups
    render json: {deploy_groups: @environment.deploy_groups}
  end

  private

  def find_environment
    @environment = Environment.find_by_param!(params[:id])
  end

  def project_versions(before_time)
    env_deploys = @deploy_groups.map(&:id)
    @projects.map do |project|
      [
        project.id,
        project.last_deploy_by_group(before_time, include_failed_deploys: @failed_deploys).
          select { |k| env_deploys.include?(k) }
      ]
    end.to_h
  end
end
