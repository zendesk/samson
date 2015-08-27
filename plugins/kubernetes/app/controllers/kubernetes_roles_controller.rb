class KubernetesRolesController < ApplicationController
  before_action :authorize_deployer!
  before_action :project
  before_action :find_role, only: [:show, :edit]

  def new
    @kubernetes_role = Kubernetes::Role.new(project: project, ram: 512, cpu: 0.2, replicas: 1)
  end

  def create
    @kubernetes_role = @project.roles.build(new_role_params)
    @kubernetes_role.deploy_strategy = 'rolling_update'    # temporarily hardcoded
    @kubernetes_role.save

    respond_to do |format|
      format.html do
        if @kubernetes_role.persisted?
          redirect_to project_kubernetes_roles_path(@project)
        else
          render :new, status: 422
        end
      end

      format.json do
        render json: {}, status: @kubernetes_role.persisted? ? 200 : 422
      end
    end
  end

  def index
    @kubernetes_role_list = project.roles.order('id desc')
  end

  def show
    # TODO
  end

  def edit
    # TODO
  end

  private

  def project
    @project ||= Project.find_by_param!(params[:project_id])
  end
  helper_method :project

  def find_role
    @kubernetes_role = project.roles.find(params[:id])
  end

  def new_role_params
    params.require(:kubernetes_role).permit(:name, :config_file, :service_name, :ram, :cpu, :replicas)
  end
end
