class KubernetesProjectController < ApplicationController
  before_action :authorize_deployer!
  before_action :project

  def show
    @release_group_list = project.kubernetes_release_groups.order('id desc')
    @kubernetes_role_list = project.roles.order('id desc')
  end

  private

  def project
    @project ||= Project.find_by_param!(params[:id])
  end
  helper_method :project
end
