class KubernetesProjectController < ApplicationController
  include CurrentProject
  before_action :authorize_project_deployer!

  def show
    @releases_list = current_project.kubernetes_releases.order('id desc')
  end

  private

  def require_project
    @project = (Project.find_by_param!(params[:id]) if params[:id])
  end
end
