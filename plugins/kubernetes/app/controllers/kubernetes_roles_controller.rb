class KubernetesRolesController < ApplicationController
  include ProjectLevelAuthorization

  before_action :authorize_project_deployer!, only: [:index]
  before_action :authorize_project_admin!, only: [:show, :update, :refresh]

  def index
    render json: current_project.roles.not_deleted.order('id desc'), root: false
  end

  def show
    render json: Kubernetes::Role.find(params[:id]), root: false
  end

  def update
    role = Kubernetes::Role.find(params[:id])
    if role.update(role_params)
      render status: :ok, json: role
    else
      render status: :bad_request, json: {errors: role.errors.full_messages}
    end
  end

  def refresh
    roles = current_project.refresh_kubernetes_roles!(refresh_params)
    if roles.to_a.empty?
      render status: :not_found, json: {}
    else
      render status: :ok, json: roles, root: false
    end
  end

  private

  def role_params
    params.require(:kubernetes_role).permit(:name, :config_file, :service_name, :ram, :cpu, :replicas, :deploy_strategy)
  end

  def refresh_params
    params.require(:ref)
  end
end
