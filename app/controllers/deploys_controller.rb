require 'csv'

class DeploysController < ApplicationController
  include ProjectLevelAuthorization

  skip_before_action :require_project, only: [:active, :active_count, :recent, :changeset]

  before_action :authorize_project_deployer!, only: [:new, :create, :confirm, :buddy_check, :destroy]
  before_action :find_deploy, except: [:index, :recent, :active, :active_count, :new, :create, :confirm, :search]
  before_action :stage, only: :new

  def index
    scope = current_project.try(:deploys) || Deploy
    @deploys = if params[:ids]
      Kaminari.paginate_array(scope.find(params[:ids])).page(1).per(1000)
    else
      scope.page(params[:page])
    end

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
      format.csv do
        datetime = Time.now.strftime "%Y%m%d_%H%M"
        send_data Deploy.to_csv, type: :csv, filename: "Deploys_#{datetime}.csv"
      end
    end
  end

  # little search endpoint.  
  # takes the same tokens that are used by the filter stuff
  # on the recent deploys pages.  returrns a paginated 
  # json object or CSV of stuff that people are interested in rather than 
  # doing client side filtering.
  # params:
  #   * deployer (name of the user that started the job(s)
  #   * project_name (name of the project)
  #   * user_type (robot or not) (not implemented)
  #   * production (boolean, is this in proudction or not)
  #   * status (what is the status of this job failed|running| etc)
  #
  def search
    respond_to do |format|

      # stuff that we may have gotten from the api call
      user_type     = (defined? params[:user_type]) ? params[:user_type] : false # TODO: not sure about this

      users       = false
      projects    = false
      jobs        = false
      stages      = false

      deploys     = { :deploys => [] }

      # TODO: really need some kinda layer with error handling/messages
      # etc
      unless (params[:status].nil?)
        unless Job.valid_status?(params[:status])
          render json: { :errors => "invalid status given" }, status: 422
          return
        end
      end
      unless params[:deployer].nil?
        deployer = ActiveRecord::Base.send(:sanitize_sql_like, params[:deployer])
        users = User.where("name LIKE ?", "%#{deployer}%").pluck(:id)
        Rails.logger.debug("DEBUGG: your deployer is #{params[:deployer]} filtered : #{deployer} users found #{users}")
      end

      unless params[:project_name].nil?
        projects = Project.where(:name => params[:project_name]).pluck(:id)
      end

      # get the job ids
      if users && !params[:status].nil?
        jobs = Job.where(:user_id => users).where(:status => params[:status]).pluck(:id)
      elsif  users && params[:status].nil?
        jobs = Job.where(:user_id => users).pluck(:id)
      elsif  !users && !params[:status].nil?
        jobs = Job.where(:status => params[:status]).pluck(:id)
      end

      
      #get the possible stage ids
      if projects && !params[:production].nil?
        stages = Stage.where(:project_id => projects).where(:production => production).pluck(:id)
      elsif  projects && params[:production].nil?
        stages = Stage.where(:project_id => projects).pluck(:id)
      elsif  !projects && !params[:production].nil?
        stages = Stage.where(:production => params[:production]).pluck(:id)
      end

      if stages && jobs
        deploys = Deploy.where(:stage_id => stages).where(:job_id => jobs).page(params[:page]).per(30)
      elsif !stages && jobs
        deploys = Deploy.where(:job_id => jobs).page(params[:page]).per(30)
      elsif stages && !jobs
        deploys = Deploy.where(:stage_id => stages).page(params[:page]).per(30)
      end

      format.json do
        render json: deploys
      end
      format.csv do
        datetime = Time.now.strftime "%Y%m%d_%H%M"
        send_data deploys.to_csv, type: :csv, filename: "deploy_search_results#{datetime}.csv"
      end
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
        render json: @deploy.to_json, status: @deploy.persisted? ? :created : 422, location: [current_project, @deploy]
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

    redirect_to [current_project, @deploy]
  end

  protected

  def deploy_permitted_params
    [ :reference, :stage_id ] + Samson::Hooks.fire(:deploy_permitted_params)
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
