# frozen_string_literal: true
require 'csv'

class DeploysController < ApplicationController
  include CurrentProject

  skip_before_action :require_project, only: [:active, :active_count, :changeset]

  before_action :authorize_project_deployer!, except: [:index, :show, :active, :active_count, :changeset]
  before_action :find_deploy, except: [:index, :active, :active_count, :new, :create, :confirm]
  before_action :stage, only: :new

  def active
    @deploys = deploys_scope.active
    render partial: 'deploys/table', layout: false if params[:partial]
  end

  # Returns a paginated json object of deploys that people are
  # interested in rather than doing client side filtering.
  # params:
  #   * deployer (name of the user that started the job(s), this is a fuzzy match
  #   * project_name (name of the project)
  #   * production (boolean, is this in proudction or not)
  #   * status (what is the status of this job failed|running| etc)
  def index
    @deploys =
      if ids = params[:ids]
        Kaminari.paginate_array(deploys_scope.find(ids)).page(1).per(1000)
      else
        search
      end

    return if performed?

    respond_to do |format|
      format.json do
        render_json_with_includes :deploys, @deploys, allowed: [:job, :project, :user, :stage]
      end
      format.csv do
        datetime = Time.now.strftime "%Y%m%d_%H%M"
        send_data as_csv, type: :csv, filename: "Deploys_search_#{datetime}.csv"
      end
      format.html
    end
  end

  def new
    @deploy = current_project.deploys.build(params.except(:project_id).permit(:stage_id, :reference))
  end

  def create
    deploy_service = DeployService.new(current_user)
    @deploy = deploy_service.deploy(stage, deploy_params)

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
        render json: @deploy, status: status, location: [current_project, @deploy]
      end
    end
  end

  def confirm
    @changeset = Deploy.new(stage: stage, reference: reference, project: current_project).changeset
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
          filename: "#{current_project.name}-#{@deploy.stage.name.parameterize}-#{@deploy.id}-#{datetime}.log",
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
    if @deploy.can_be_cancelled_by?(current_user)
      @deploy.cancel(current_user)
    else
      flash[:error] = "You do not have privileges to cancel this deploy."
    end

    redirect_to [current_project, @deploy]
  end

  protected

  def search
    search = params[:search] || {}
    status = search[:status].presence

    if status && !Job.valid_status?(status)
      render json: { errors: "invalid status given" }, status: 400
      return
    end

    if deployer = search[:deployer].presence
      users = User.where(
        "name LIKE ?", "%#{ActiveRecord::Base.send(:sanitize_sql_like, deployer)}%"
      ).pluck(:id)
    end

    if project_name = search[:project_name].presence
      projects = Project.where(
        "name LIKE ?", "%#{ActiveRecord::Base.send(:sanitize_sql_like, project_name)}%"
      ).pluck(:id)
    end

    if users || status
      jobs = Job
      jobs = jobs.where(user: users) if users
      jobs = jobs.where(status: status) if status
    end

    production = search[:production].presence
    code_deployed = search[:code_deployed].presence
    group = search[:group].presence
    if group || projects || !code_deployed.nil? || !production.nil?
      stages = Stage
      if group
        stages = stages.where(id: stage_ids_for_group(group))
      end
      if projects
        stages = stages.where(project: projects)
      end
      unless code_deployed.nil?
        stages = stages.where(no_code_deployed: param_to_bool(code_deployed))
      end
      unless production.nil?
        production = param_to_bool(production)
        stages = stages.select { |stage| stage.production? == production }
      end
    end

    deploys = deploys_scope
    deploys = deploys.where(stage: stages) if stages
    deploys = deploys.where(job: jobs) if jobs
    if updated_at = search[:updated_at].presence
      deploys = deploys.where("updated_at between ? AND ?", *updated_at)
    end
    deploys.page(page).per(30)
  end

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

  def deploys_scope
    current_project&.deploys || Deploy
  end

  def param_to_bool(param)
    !ActiveModel::Type::Boolean::FALSE_VALUES.include?(param)
  end

  def stage_ids_for_group(group)
    group_type, group_id = GroupScope.split(group)
    case group_type
    when "Environment" then id = DeployGroup.where(environment_id: group_id).pluck(:id)
    when "DeployGroup" then id = group_id
    else raise "Unsupported type #{group_type}"
    end
    DeployGroupsStage.where(deploy_group_id: id).pluck(:stage_id)
  end

  # Creates a CSV for @deploys as a result of the search query limited to 1000 for speed
  def as_csv
    max = 1000
    csv_limit = [(params[:limit].presence || max).to_i, max].min
    deploys = @deploys.limit(csv_limit + 1).to_a
    deploy_count = deploys.length
    deploys.pop if deploy_count > csv_limit
    CSV.generate do |csv|
      csv << Deploy.csv_header
      deploys.each { |deploy| csv << deploy.as_csv }
      csv << ['-', 'count:', [deploy_count, csv_limit].min]
      csv << ['-', 'params:', params]
      if deploy_count > csv_limit
        csv << ['-', 'There are more records. Generate a full report at']
        csv << ['-', new_csv_export_url]
      end
    end
  end
end
