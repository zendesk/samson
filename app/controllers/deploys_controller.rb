class DeploysController < ApplicationController

  rescue_from ActiveRecord::RecordNotFound do |error|
    flash[:error] = "Deploy not found."
    redirect_to root_path
  end

  before_filter :authorize_deployer!, only: [:create, :update, :destroy]
  before_filter :find_project, except: [:index, :active]
  before_filter :find_deploy, except: [:index, :active, :new, :create]

  def index
    @deploys = Deploy.limit(10).order("created_at DESC")
  end

  def active
    @deploys = Deploy.active.limit(10).order("created_at DESC")
    render :index
  end

  def new
    @deploy = @project.deploys.build(stage_id: params[:stage_id])
  end

  def create
    reference = deploy_params[:reference]
    stage = @project.stages.find(deploy_params[:stage_id])
    deploy_service = DeployService.new(@project, current_user)
    deploy = deploy_service.deploy!(stage, reference)

    redirect_to project_deploy_path(@project, deploy)
  end

  def show
  end

  def destroy
    if !@deploy.started_by?(current_user)
      head :forbidden
    else
      @deploy.stop!

      head :ok
    end
  end

  protected

  def deploy_params
    params.require(:deploy).permit(:reference, :stage_id)
  end

  def find_project
    @project = Project.find(params[:project_id])
  end

  def find_deploy
    @deploy = Deploy.find(params[:id])
  end
end
