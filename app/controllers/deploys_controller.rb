class DeploysController < ApplicationController
  before_action :authorize_deployer!, only: [:new, :create, :confirm, :update, :destroy, :buddy_check, :pending_start]
  before_action :find_project
  before_action :find_deploy, except: [:index, :recent, :active, :new, :create, :confirm]

  def index
    @page = params[:page]
    @deploys = @project.deploys.includes(:stage, job: :user).page(@page)

    respond_to do |format|
      format.html
      format.json { render json: @deploys }
    end
  end

  def active
    scope = @project ? @project.deploys : Deploy.includes(:stage)
    @deploys = scope.active.includes(job: :user).page(params[:page])

    respond_to do |format|
      format.html
      format.json { render json: @deploys }
    end
  end

  def recent
    respond_to do |format|
      format.html
      format.json do
        render json: Deploy.includes(:stage, job: :user).page(params[:page]).per(30)
      end
    end
  end

  def new
    @deploy = @project.deploys.build(params.permit(:stage_id, :reference))
  end

  def create
    deploy_service = DeployService.new(@project, current_user)
    @deploy = deploy_service.deploy!(stage, reference)

    respond_to do |format|
      format.html do
        if @deploy.persisted?
          redirect_to project_deploy_path(@project, @deploy)
        else
          render :new
        end
      end

      format.json do
        render json: {}, status: @deploy.persisted? ? 200 : 422
      end
    end
  end

  def confirm
    @changeset = Deploy.new(stage: stage, reference: reference).changeset
    render 'changeset', layout: false
  end

  def buddy_check
    if @deploy.pending?
      @deploy.confirm_buddy!(current_user)
    end

    redirect_to project_deploy_path(@project, @deploy)
  end

  def pending_start
    if @deploy.pending_non_production?
      @deploy.pending_start!
    end

    redirect_to project_deploy_path(@project, @deploy)
  end

  def show
    respond_to do |format|
      format.html
      format.text do
        datetime = @deploy.updated_at.strftime "%Y%m%d_%H%M%Z"
        send_data @deploy.output,
          filename: "#{@project.repo_name}-#{@deploy.stage.name.parameterize}-#{@deploy.id}-#{datetime}.log",
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
    if @deploy.can_be_stopped_by?(current_user)
      @deploy.stop!
    else
      flash[:error] = "You do not have privileges to stop this deploy."
    end
    redirect_to project_deploy_path(@project, @deploy)
  end

  protected

  def reference
    deploy_params[:reference].strip
  end

  def stage
    @stage ||= @project.stages.find(deploy_params[:stage_id])
  end

  def deploy_params
    params.require(:deploy).permit(:reference, :stage_id)
  end

  def find_project
    @project = Project.find_by_param!(params[:project_id]) if params[:project_id]
  end

  def find_deploy
    @deploy = Deploy.includes(stage: [:new_relic_applications]).find(params[:id])
  end
end
