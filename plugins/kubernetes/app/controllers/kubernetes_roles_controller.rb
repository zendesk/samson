class KubernetesRolesController < ApplicationController
  include ProjectLevelAuthorization

  before_action :authorize_project_deployer!, only: [:index]
  before_action :authorize_project_admin!, only: [:show, :update, :new, :create]

  def index
    render json: current_project.roles.order('id desc'), root: false
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

  def new
    # TODO : READ DEFAULT VALUES FROM YAML FILE
    render json: Kubernetes::Role.new(project: current_project, ram: 512, cpu: 0.2, replicas: 1, deploy_strategy: 'rolling_update'), root: false
  end

  def create
    role = current_project.roles.build(role_params)
    role.save

    if role.persisted?
      render status: :created, json: role
    else
      render status: :bad_request, json: {errors: role.errors.full_messages}
    end
  end

  private

  def role_params
    params.require(:kubernetes_role).permit(:name, :config_file, :service_name, :ram, :cpu, :replicas, :deploy_strategy)
  end
end
