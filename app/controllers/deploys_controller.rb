class DeploysController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound do |error|
    flash[:error] = "Deploy not found."
    redirect_to root_path
  end

  before_filter :authorize_deployer!, only: [:new, :create, :confirm, :update, :destroy]
  before_filter :find_project, except: [:recent, :active]
  before_filter :find_deploy, except: [:index, :recent, :active, :new, :create, :confirm]

  def index
    @deploys = @project.deploys.includes(:stage, job: :user).page(params[:page])
  end

  def active
    @deploys = Deploy.includes(:stage, job: :user).active.page(params[:page])
  end

  def recent
    respond_to do |format|
      format.html
      format.json do
        @deploys = Deploy.includes(:stage, job: :user).page(params[:page])
      end
    end
  end

  def new
    @deploy = @project.deploys.build(params.permit(:stage_id, :reference))
  end

  def create
    stage = @project.stages.find(deploy_params[:stage_id])
    reference = deploy_params[:reference].strip

    deploy_service = DeployService.new(@project, current_user)
    @deploy = deploy_service.deploy!(stage, reference)

    if @deploy.persisted?
      redirect_to project_deploy_path(@project, @deploy)
    else
      render :new
    end
  end

  def confirm
    reference = deploy_params[:reference]

    stage = @project.stages.find(deploy_params[:stage_id])
    previous_commit = stage.last_deploy.try(:commit)

    @changeset = Changeset.find(@project.github_repo, previous_commit, reference)

    render 'changeset', layout: false
  end

  def show
    respond_to do |format|
      format.html
      format.text do
        send_data @deploy.output,
          filename: "#{@project.repo_name}-#{@deploy.stage.name}-#{@deploy.id}.log",
          type: 'text/plain'
      end
    end
  end

  def changeset
    if stale?(etag: @deploy.cache_key, last_modified: @deploy.updated_at)
      @changeset = @deploy.changeset
      render 'changeset', layout: false
    end
  end

  def destroy
    if @deploy.started_by?(current_user) || current_user.is_admin?
      @deploy.stop!

      head :ok
    else
      head :forbidden
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
    @deploy = Deploy.includes(stage: [:new_relic_applications]).find(params[:id])
  end
end
