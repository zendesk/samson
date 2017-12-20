# frozen_string_literal: true
class StagesController < ApplicationController
  include CurrentProject

  skip_before_action :login_user, if: :badge?

  before_action :authorize_resource!
  before_action :check_token, if: :badge?
  before_action :find_stage, only: [:show, :edit, :update, :destroy, :clone]

  def index
    @stages = @project.stages

    respond_to do |format|
      format.html
      format.json { render json: {stages: @stages} }
    end
  end

  def show
    respond_to do |format|
      format.html do
        @deploys = @stage.deploys.page(page)
      end
      format.json do
        stage = @stage.as_json
        if params[:include].to_s.split(',').include?("kubernetes_matrix")
          stage[:kubernetes_matrix] = Kubernetes::DeployGroupRole.matrix(@stage)
        end
        render json: { stage: stage }
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
    @stage = @project.stages.new
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
    @stage.soft_delete!(validate: false)
    redirect_to @project
  end

  def reorder
    Stage.reset_order(params[:stage_id])
    head :ok
  end

  def clone
    @stage = Stage.build_clone(@stage)
    if request.post?
      @stage.attributes = stage_params
      @stage.save!
      render json: {stage: @stage}
    else
      render :new
    end
  end

  private

  def badge_safe(string)
    CGI.escape(string).
      gsub('+', '%20').
      gsub(/-+/, '--')
  end

  def check_token
    return if Rack::Utils.secure_compare(params[:token].to_s, Rails.application.config.samson.badge_token)
    head :not_found
  end

  def badge?
    action_name == 'show' && request.format == Mime[:svg]
  end

  def stage_params
    params.require(:stage).permit(stage_permitted_params)
  end

  def find_stage
    return if @stage = current_project.stages.find_by_param(params[:id])
    badge? ? head(:not_found) : raise(ActiveRecord::RecordNotFound)
  end

  def stage_permitted_params
    [
      :name,
      :command,
      :confirm,
      :permalink,
      :dashboard,
      :production,
      :notify_email_address,
      :deploy_on_release,
      :email_committers_on_automated_deploy_failure,
      :static_emails_on_automated_deploy_failure,
      :no_code_deployed,
      :is_template,
      :run_in_parallel,
      :cancel_queued_deploys,
      :periodical_deploy,
      :no_reference_selection,
      :builds_in_environment,
      {
        deploy_group_ids: [],
        command_ids: []
      }
    ] + Samson::Hooks.fire(:stage_permitted_params).flatten
  end
end
