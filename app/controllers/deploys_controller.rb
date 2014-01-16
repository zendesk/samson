class DeploysController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound do |error|
    flash[:error] = "Deploy not found."
    redirect_to root_path
  end

  before_filter :authorize_deployer!, only: [:create, :update, :destroy]
  before_filter :find_project, except: [:recent, :active]
  before_filter :find_deploy, except: [:index, :recent, :active, :new, :create]

  def index
    @deploys = Deploy.page(params[:page])
  end

  def active
    @deploys = Deploy.active.page(params[:page])
  end

  def recent
    @deploys = Deploy.page(params[:page])
  end

  def new
    @deploy = @project.deploys.build(stage_id: params[:stage_id])
  end

  def create
    deploy! @project.stages.find(deploy_params[:stage_id]), deploy_params[:reference]

    post_deploy
  end

  def show
    @changeset = Changeset.new(@project.github_repo, @deploy.previous_commit, @deploy.commit)
  end

  def destroy
    if @deploy.started_by?(current_user) || current_user.is_admin?
      @deploy.stop!

      head :ok
    else
      head :forbidden
    end
  end

  def retry
    deploy! @deploy.stage, @deploy.reference

    flash[:notice] = "This is a redeploy of #{@deploy.reference} to #{@deploy.stage.name}"
    post_deploy
  end

  protected

  def post_deploy
    if @deploy.persisted?
      redirect_to project_deploy_path(@project, @deploy)
    else
      render :new
    end
  end

  def deploy!(stage, reference)
    deploy_service = DeployService.new(@project, current_user)
    @deploy = deploy_service.deploy!(stage, reference)
  end

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
