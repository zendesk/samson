class KubernetesProjectController < ApplicationController
  include CurrentProject
  before_action :authorize_project_deployer!

  def show
    if !ENV['DOCKER_FEATURE'] && !Rails.env.test?
      render text: "Kubernetes needs docker to be enabled, set DOCKER_FEATURE=1"
    else
      @releases_list = current_project.kubernetes_releases.order('id desc')
    end
  end

  private

  def require_project
    @project = (Project.find_by_param!(params[:id]) if params[:id])
  end
end
