class KubernetesReleasesController < ApplicationController
  include CurrentProject

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
    attributes = params.require(:kubernetes_release).permit(:build_id, deploy_groups: [:id, roles: [:id, :replicas]])
      .merge(user: current_user, project: current_project)

    # UI does not have cpu/ram, so use the defaults
    attributes.fetch(:deploy_groups).each do |dg|
      dg.fetch(:roles).each do |role|
        r = ::Kubernetes::Role.find(role.fetch(:id))
        role[:cpu] = r.cpu
        role[:ram] = r.ram
      end
    end

    attributes
  end
end
