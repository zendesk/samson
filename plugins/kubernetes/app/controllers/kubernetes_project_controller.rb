class KubernetesProjectController < ApplicationController
  include ProjectLevelAuthorization
  before_action :authorize_project_deployer!

  def show
    @release_group_list = current_project.kubernetes_release_groups.order('id desc')
    @kubernetes_role_list = current_project.roles.order('id desc')
  end

  private

  def require_project
    @project = (Project.find_by_param!(params[:id]) if params[:id])
  end
end
