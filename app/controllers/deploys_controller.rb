class DeploysController < ApplicationController
  load_resource :project, find_by: :param, except: [ :recent ]
  load_resource :stage, find_by: :param, only: :new
  load_resource except: [ :index, :recent, :active, :new, :create, :confirm ]
  authorize_resource only: [ :new, :create, :destroy ]
  before_action :authorize_as_create, only: [ :confirm, :pending_start, :buddy_check ]

  def index
    @deploys = @project.deploys.page(params[:page])

    respond_to do |format|
      format.html
      format.json { render json: @deploys }
    end
  end

  def active
    @project = Project.find_by_param!(params[:project_id]) if params[:project_id]
    scope = (@project ? @project.deploys : Deploy)
    @deploys = scope.active.page(params[:page])

    respond_to do |format|
      format.html
      format.json { render json: @deploys }
    end
  end

  def recent
    respond_to do |format|
      format.html
      format.json do
        render json: Deploy.page(params[:page]).per(30)
      end
    end
  end

  def new
    @deploy = @project.deploys.build(params.except(:project_id).permit(:stage_id, :reference))
  end

  def create
    deploy_service = DeployService.new(@project, current_user)
    @deploy = deploy_service.deploy!(stage, reference)

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
    @deploy.stop!
    redirect_to [@project, @deploy]
  end

  protected

  def reference
    deploy_params[:reference].strip
  end

  def stage
    @stage ||= @project.stages.find_by_param!(params[:stage_id])
  end

  def deploy_params
    params.require(:deploy).permit(:reference, :stage_id)
  end

  def authorize_as_create
    authorize! :create, Deploy
  end
end
