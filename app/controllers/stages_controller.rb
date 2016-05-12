class StagesController < ApplicationController
  include CurrentProject
  include StagePermittedParams

  skip_around_action :login_user, if: :badge?

  before_action :authorize_project_deployer!, unless: :badge?
  before_action :authorize_project_admin!, except: [:index, :show]
  before_action :check_token, if: :badge?
  before_action :find_stage, only: [:show, :edit, :update, :destroy, :clone]

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
        @deploys = @stage.deploys.page(params[:page])
      end
      format.svg do
        badge =
          if deploy = @stage.last_successful_deploy
            "#{badge_safe(@stage.name)}-#{badge_safe(deploy.short_reference)}-green"
          else
            "#{badge_safe(@stage.name)}-None-red"
          end
        redirect_to "https://img.shields.io/badge/#{badge}.svg"
      end
    end
  end

  def new
    @stage = @project.stages.build(command_ids: Command.global.pluck(:id))
  end

  def create
    # Need to ensure project is already associated
    @stage = @project.stages.build
    @stage.attributes = stage_params

    if @stage.save
      redirect_to [@project, @stage]
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @stage.update_attributes(stage_params)
      redirect_to [@project, @stage]
    else
      render :edit
    end
  end

  def destroy
    @stage.soft_delete!
    redirect_to @project
  end

  def reorder
    Stage.reset_order(params[:stage_id])
    head :ok
  end

  def clone
    @stage = Stage.build_clone(@stage)
    render :new
  end

  private

  def badge_safe(string)
    CGI.escape(string).
      gsub('+', '%20').
      gsub(/-+/, '--')
  end

  def check_token
    unless params[:token] == Rails.application.config.samson.badge_token
      raise ActiveRecord::RecordNotFound
    end
  end

  def badge?
    action_name == 'show' && request.format == Mime[:svg]
  end

  def stage_params
    params.require(:stage).permit(stage_permitted_params)
  end

  def find_stage
    @stage = current_project.stages.find_by_param!(params[:id])
  end
end
