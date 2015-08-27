class KubernetesProjectController < ApplicationController
  before_action :authorize_deployer!
  before_action :project

  def show
    @kuber_release_list = project.kubernetes_releases.order('id desc')
    @kubernetes_role_list = project.roles.order('id desc')
  end

  private

  def project
    @project ||= Project.find_by_param!(params[:id])
  end
  helper_method :project
end
