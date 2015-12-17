class KubernetesReleasesController < ApplicationController
  include ProjectLevelAuthorization

  before_action :authorize_project_deployer!

  def index
    render json: current_project.kubernetes_releases.order('id desc'), root: false
  end

  def create
    release = Kubernetes::Release.create_release(release_params)
    if release.persisted?
      KuberDeployService.new(release).deploy!
      render status: :created, json: release
    else
      render status: :bad_request, json: { errors: release.errors.full_messages }
    end
  end

  private

  def release_params
    params.require(:kubernetes_release).permit(:build_id, deploy_groups: [:id, roles: [:id, :replicas]])
      .merge(user: current_user)
  end
end
