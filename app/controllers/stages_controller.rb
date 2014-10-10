class StagesController < ApplicationController
  skip_before_filter :login_users, if: :badge?
  before_filter :authorize_admin!, except: [:index, :show]
  before_filter :authorize_deployer!, unless: :badge?
  before_filter :check_token, if: :badge?
  before_filter :find_project
  before_filter :find_stage, only: [:show, :edit, :update, :destroy, :clone]

  rescue_from ActiveRecord::RecordNotFound do
    if @project
      redirect_to project_path(@project)
    else
      redirect_to root_path
    end
  end

  def index
    @stages = @project.stages

    respond_to do |format|
      format.html
      format.json do
        render json: @stages
      end
    end
  end

  def show
    respond_to do |format|
      format.html do
        @deploys = @stage.deploys.includes(:stage, job: :user).page(params[:page])
      end
      format.svg do
        badge = if deploy = @stage.last_deploy
          "#{badge_safe(@stage.name)}-#{badge_safe(deploy.short_reference)}-green"
        else
          "#{badge_safe(@stage.name)}-None-red"
        end

        if stale?(etag: badge)
          expires_in 1.minute, :public => true
          image = open("http://img.shields.io/badge/#{badge}.svg").read
          render text: image, content_type: Mime::SVG
        end
      end
    end
  end

  def new
    @stage = @project.stages.build(command_ids: Command.global.pluck(:id))
    @stage.flowdock_flows.build
    @stage.new_relic_applications.build
  end

  def create
    # Need to ensure project is already associated
    @stage = @project.stages.build
    @stage.attributes = stage_params

    if @stage.save
      redirect_to project_stage_path(@project, @stage)
    else
      flash[:error] = @stage.errors.full_messages

      @stage.flowdock_flows.build
      @stage.new_relic_applications.build

      render :new
    end
  end

  def edit
    @stage.flowdock_flows.build
    @stage.new_relic_applications.build
  end

  def update
    if @stage.update_attributes(stage_params)
      redirect_to project_stage_path(@project, @stage)
    else
      flash[:error] = @stage.errors.full_messages

      @stage.flowdock_flows.build
      @stage.new_relic_applications.build

      render :edit
    end
  end

  def destroy
    @stage.soft_delete!
    redirect_to project_path(@project)
  end

  def reorder
    Stage.reorder(params[:stage_id])

    head :ok
  end

  def clone
    @stage = Stage.build_clone(@stage)
    render :new
  end

  private

  def badge_safe(string)
    CGI.escape(string.gsub('&', '&amp;')).gsub('-', '&mdash;').gsub('+','%20')
  end

  def check_token
    unless params[:token] == Rails.application.config.samson.badge_token
      raise ActiveRecord::RecordNotFound
    end
  end

  def badge?
    action_name == 'show' && request.format == Mime::SVG
  end

  def stage_params
    params.require(:stage).permit(
      :name, :command, :confirm,
      :production,
      :notify_email_address,
      :deploy_on_release,
      :datadog_tags,
      :update_github_pull_requests,
      :update_github_pull_requests_on_failure,
      command_ids: [],
      flowdock_flows_attributes: [:id, :name, :token, :_destroy],
      new_relic_applications_attributes: [:id, :name, :_destroy]
    )
  end

  def find_project
    @project = Project.find_by_param!(params[:project_id])
  end

  def find_stage
    @stage = @project.stages.find(params[:id])
  end
end
