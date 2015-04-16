require 'open-uri' # needed to fetch from img.shields.io using open()

class StagesController < ApplicationController
  include StagePermittedParams

  skip_before_action :login_users, if: :badge?
  before_action :check_token, if: :badge?
  before_action :get_environments, only: [:new, :create, :edit, :update, :clone]

  load_resource :project, find_by: :param
  load_resource through: :project, find_by: :param, only: [ :show, :edit, :update, :create, :destroy, :clone ]
  authorize_resource except: :show

  def index
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
        authorize! :read, @stage
        @deploys = @stage.deploys.page(params[:page])
      end
      format.svg do
        badge = if deploy = @stage.last_successful_deploy
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
    @stage.new_relic_applications.build
  end

  def create
    if @stage.save
      redirect_to [@project, @stage]
    else
      flash[:error] = @stage.errors.full_messages

      @stage.new_relic_applications.build

      render :new
    end
  end

  def edit
    @stage.new_relic_applications.build
  end

  def update
    if @stage.update_attributes(stage_params)
      redirect_to [@project, @stage]
    else
      flash[:error] = @stage.errors.full_messages

      @stage.new_relic_applications.build

      render :edit
    end
  end

  def destroy
    @stage.soft_delete!
    redirect_to @project
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
    CGI.escape(string)
      .gsub('+','%20')
      .gsub(/-+/,'--')
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
    params.require(:stage).permit(stage_permitted_params)
  end

  def find_stage
    @stage = @project.stages.find_by_param!(params[:id])
  end

  def get_environments
    @environments = Environment.all
  end
end
