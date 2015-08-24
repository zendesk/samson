class ProjectRolesController < ApplicationController
  before_action :authorize_deployer!
  before_action :project
  before_action :find_project_role, only: [:show, :edit]

  def new
    @project_role = ProjectRole.new(project: project, ram: 512, cpu: 0.2, replicas: 1)
  end

  def create
    @project_role = @project.roles.build(new_role_params)
    @project_role.deploy_strategy = 'rolling_update'    # temporarily hardcoded
    @project_role.save

    respond_to do |format|
      format.html do
        if @project_role.persisted?
          redirect_to project_project_roles_path(@project)
        else
          render :new, status: 422
        end
      end

      format.json do
        render json: {}, status: @project_role.persisted? ? 200 : 422
      end
    end
  end

  def index
    @project_role_list = project.roles.order('id desc')
  end

  def show

  end

  def edit

  end

  private

  def project
    @project ||= Project.find_by_param!(params[:project_id])
  end
  helper_method :project

  def find_project_role
    @project_role = project.roles.find(params[:id])
  end

  def new_role_params
    params.require(:project_role).permit(:name, :config_file, :service_name, :ram, :cpu, :replicas)
  end
end
