# frozen_string_literal: true

class StagesController < ApplicationController
  include CurrentProject

  skip_before_action :login_user, if: :badge?

  before_action :authorize_resource!
  before_action :check_token, if: :badge?
  before_action :find_stage, only: [:show, :edit, :update, :destroy, :clone]
  helper_method :can_change_no_code_deployed?

  def index
    @stages = @project.stages
    multi_format_render(
      successful: true,
      on_success_html: -> {},
      on_success_json: -> { render_as_json :stages, @stages }
    )
  end

  def show
    respond_to do |format|
      format.html do
        @pagy, @deploys = pagy(@stage.deploys, page: page, items: 15)
      end
      format.json do
        render_as_json :stage, @stage, allowed_includes: [
          :last_deploy, :last_successful_deploy, :active_deploy
        ] do |reply|
          # deprecated way of inclusion, do not add more
          if params[:include] == "kubernetes_matrix"
            reply[:stage][:kubernetes_matrix] = Kubernetes::DeployGroupRole.matrix(@stage)
          end
        end
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
    is_saved = @stage.save
    multi_format_render(
      successful: is_saved,
      on_success_html: -> { redirect_to [@project, @stage] },
      on_error_html: -> { render :new },
      on_success_json: -> { render_as_json :stage, @stage },
      on_error_json: -> { render_json_error :unprocessable_entity, @stage.errors }
    )
  end

  def edit
  end

  def update
    is_saved = @stage.update_attributes(stage_params)
    multi_format_render(
      successful: is_saved,
      on_success_html: -> { redirect_to [@project, @stage] },
      on_error_html: -> { render :edit },
      on_success_json: -> { render_as_json :stage, @stage },
      on_error_json: -> { render_json_error :unprocessable_entity, @stage.errors }
    )
  end

  def destroy
    is_destroyed = @stage.soft_delete!(validate: false)
    multi_format_render(
      successful: is_destroyed,
      on_success_html: -> { redirect_to @project },
      on_success_json: -> { head :ok }
    )
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

  def can_change_no_code_deployed?
    current_user.admin?
  end

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
    permitted_params = [
      :builds_in_environment,
      :cancel_queued_deploys,
      :confirm,
      :dashboard,
      :default_reference,
      :deploy_on_release,
      :email_committers_on_automated_deploy_failure,
      :is_template,
      :name,
      :no_reference_selection,
      :notify_email_address,
      :periodical_deploy,
      :permalink,
      :production,
      :run_in_parallel,
      :allow_redeploy_previous_when_failed,
      :static_emails_on_automated_deploy_failure,
      :full_checkout,
      {
        deploy_group_ids: [],
        command_ids: []
      }
    ]
    permitted_params << :no_code_deployed if can_change_no_code_deployed?
    permitted_params + Samson::Hooks.fire(:stage_permitted_params).flatten
  end
end
