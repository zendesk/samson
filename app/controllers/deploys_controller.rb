class DeploysController < ApplicationController
  include CurrentProject

  before_action :authorize_deployer!, only: [:new, :create, :confirm, :update, :destroy, :buddy_check, :pending_start]
  before_action except: [:active, :active_count, :recent, :changeset] do
    find_project(params[:project_id])
  end
  before_action :find_deploy, except: [:index, :recent, :active, :active_count, :new, :create, :confirm]
  before_action :stage, only: :new

  def index
    @deploys = @project.deploys.page(params[:page])

    respond_to do |format|
      format.html
      format.json { render json: @deploys }
    end
  end

  def active_count
    render json: { deploy_count: active_deploy_scope.count }
  end

  def active
    @deploys = active_deploy_scope

    respond_to do |format|
      format.html { render 'recent', locals: { title: 'Current Deploys', show_filters: false, controller: 'currentDeploysCtrl' } }
      format.json { render json: @deploys }
    end
  end

  def recent
    respond_to do |format|
      format.html { render 'recent', locals: { title: 'Recent Deploys', show_filters: true, controller: 'TimelineCtrl' } }
      format.json do
        render json: Deploy.page(params[:page]).per(30)
      end
    end
  end

  def new
    @deploy = @project.deploys.build(params.except(:project_id).permit(:stage_id, :reference))
  end

  def create
    deploy_service = DeployService.new(current_user)
    @deploy = deploy_service.deploy!(stage, deploy_params)

    respond_to do |format|
      format.html do
        if @deploy.persisted?
          redirect_to [@project, @deploy]
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

    redirect_to [@project, @deploy]
  end

  def pending_start
    if @deploy.pending_non_production?
      @deploy.pending_start!
    end

    redirect_to [@project, @deploy]
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
      DeployService.new(current_user).stop!(@deploy)
    else
      flash[:error] = "You do not have privileges to stop this deploy."
    end

    redirect_to [@project, @deploy]
  end

  protected

  def deploy_permitted_params
    [ :reference, :stage_id ] + Samson::Hooks.fire(:deploy_permitted_params)
  end

  def reference
    deploy_params[:reference].strip
  end

  def stage
    @stage ||= @project.stages.find_by_param!(params[:stage_id])
  end

  def deploy_params
    params.require(:deploy).permit(deploy_permitted_params)
  end

  def find_deploy
    @deploy = Deploy.find(params[:id])
  end

  def active_deploy_scope
    @project ? @project.deploys.active : Deploy.active
  end
end
