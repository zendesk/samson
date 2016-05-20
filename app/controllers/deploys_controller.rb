class DeploysController < ApplicationController
  include CurrentProject

  skip_before_action :require_project, only: [:active, :active_count, :changeset]

  before_action :authorize_project_deployer!, only: [:new, :create, :confirm, :buddy_check, :destroy]
  before_action :find_deploy, except: [:index, :active, :active_count, :new, :create, :confirm, :search]
  before_action :stage, only: :new

  def index
    scope = current_project.try(:deploys) || Deploy
    @deploys =
      if params[:ids]
        Kaminari.paginate_array(scope.find(params[:ids])).page(1).per(1000)
      else
        scope.page(params[:page])
      end

    respond_to do |format|
      format.html
      format.json { render json: @deploys }
    end
  end

  def active
    @deploys = active_deploy_scope
    render partial: 'shared/deploys_table', layout: false if params[:partial]
  end

  def active_count
    render json: Deploy.active.count
  end

  # Takes the same params that are used by the client side filtering
  # on the recent deploys pages.
  # Returns a paginated json object of deploys that people are
  # interested in rather than doing client side filtering.
  # params:
  #   * deployer (name of the user that started the job(s), this is a fuzzy match
  #   * project_name (name of the project)
  #   * production (boolean, is this in proudction or not)
  #   * status (what is the status of this job failed|running| etc)

  def search
    status = params[:status].presence

    if status && !Job.valid_status?(params[:status])
      render json: { errors: "invalid status given" }, status: 400
      return
    end

    if params[:deployer].present?
      users = User.where(
        "name LIKE ?", "%#{ActiveRecord::Base.send(:sanitize_sql_like, params[:deployer])}%"
      ).pluck(:id)
    end

    if params[:project_name].present?
      projects = Project.where(
        "name LIKE ?", "%#{ActiveRecord::Base.send(:sanitize_sql_like, params[:project_name])}%"
      ).pluck(:id)
    end

    if users || status
      jobs = Job
      jobs = jobs.where(user: users) if users
      jobs = jobs.where(status: status) if status
    end

    if params[:production].present? || projects
      stages = Stage
      stages = stages.where(project: projects) if projects
      if params[:production].present?
        production = ActiveRecord::Type::Boolean.new.type_cast_from_user(params[:production])
        stages = stages.select { |stage| (stage.production? == production) }
      end
    end

    deploys = Deploy
    deploys = deploys.where(stage: stages) if stages
    deploys = deploys.where(job: jobs) if jobs
    @deploys = deploys.page(params[:page]).per(30)

    respond_to do |format|
      format.json do
        render json: @deploys
      end
      format.html
    end
  end

  def new
    @deploy = current_project.deploys.build(params.except(:project_id).permit(:stage_id, :reference))
  end

  def create
    deploy_service = DeployService.new(current_user)
    @deploy = deploy_service.deploy!(stage, deploy_params)

    respond_to do |format|
      format.html do
        if @deploy.persisted?
          redirect_to [current_project, @deploy]
        else
          render :new
        end
      end

      format.json do
        status = (@deploy.persisted? ? :created : :unprocessable_entity)
        render json: @deploy.to_json, status: status, location: [current_project, @deploy]
      end
    end
  end

  def confirm
    @changeset = Deploy.new(stage: stage, reference: reference).changeset
    render 'changeset', layout: false
  end

  def buddy_check
    @deploy.confirm_buddy!(current_user) if @deploy.pending?

    redirect_to [current_project, @deploy]
  end

  def show
    respond_to do |format|
      format.html
      format.text do
        datetime = @deploy.updated_at.strftime "%Y%m%d_%H%M%Z"
        send_data @deploy.output,
          filename: "#{current_project.repo_name}-#{@deploy.stage.name.parameterize}-#{@deploy.id}-#{datetime}.log",
          type: 'text/plain'
      end
    end
  end

  def changeset
    if stale? @deploy
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

    redirect_to [current_project, @deploy]
  end

  protected

  def deploy_permitted_params
    [:reference, :stage_id] + Samson::Hooks.fire(:deploy_permitted_params)
  end

  def reference
    deploy_params[:reference].strip
  end

  def stage
    @stage ||= current_project.stages.find_by_param!(params[:stage_id])
  end

  def deploy_params
    params.require(:deploy).permit(deploy_permitted_params)
  end

  def find_deploy
    @deploy = Deploy.find(params[:id])
  end

  def active_deploy_scope
    current_project ? current_project.deploys.active : Deploy.active
  end
end
