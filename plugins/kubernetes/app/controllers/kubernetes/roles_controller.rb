class Kubernetes::RolesController < ApplicationController
  include CurrentProject

  DEPLOYER_ACCESS = [:index, :show].freeze
  before_action :authorize_project_deployer!, only: DEPLOYER_ACCESS
  before_action :authorize_project_admin!, except: DEPLOYER_ACCESS
  before_action :find_role, only: [:show, :update, :destroy]

  def index
    @roles = ::Kubernetes::Role.not_deleted.where(project: current_project).order('name desc').to_a
    respond_to do |format|
      format.html
      format.json { render json: @roles, root: false }
    end
  end

  def seed
    Kubernetes::Role.seed!(@project, params.require(:ref))
    redirect_to action: :index
  end

  def new
    @role = Kubernetes::Role.new
  end

  def create
    @role = Kubernetes::Role.new(role_params.merge(project: @project))
    if @role.save
      redirect_to action: :index
    else
      render :new
    end
  end

  def show
  end

  def update
    if @role.update_attributes(role_params)
      redirect_to action: :index
    else
      render :show
    end
  end

  def destroy
    @role.soft_delete!
    redirect_to action: :index
  end

  private

  def find_role
    @role = Kubernetes::Role.not_deleted.find(params[:id])
  end

  def role_params
    params.require(:kubernetes_role).permit(:name, :config_file, :service_name, :deploy_strategy)
  end
end
