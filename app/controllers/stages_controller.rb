# frozen_string_literal: true

class StagesController < ResourceController
  include CurrentProject

  skip_before_action :login_user, if: :badge?

  before_action :authorize_resource!
  before_action :check_token, if: :badge?
  before_action :set_resource, only: [:show, :edit, :update, :destroy, :clone, :new, :create]
  helper_method :can_change_no_code_deployed?

  def index
    super(paginate: !request.format.html?)
  end

  def show
    respond_to do |format|
      format.html do
        @pagy, @deploys = pagy(@stage.deploys, page: params[:page], items: 15)
      end
      format.json do
        render_as_json :stage, @stage, allowed_includes: [
          :last_deploy, :last_succeeded_deploy, :active_deploy
        ] do |reply|
          # deprecated way of inclusion, do not add more
          if params[:include] == "kubernetes_matrix"
            reply[:stage][:kubernetes_matrix] = Kubernetes::DeployGroupRole.matrix(@stage)
          end
        end
      end
      format.svg do
        badge =
          if deploy = @stage.last_succeeded_deploy
            "#{badge_safe(@stage.name)}-#{badge_safe(deploy.short_reference)}-green"
          else
            "#{badge_safe(@stage.name)}-None-red"
          end
        redirect_to "https://img.shields.io/badge/#{badge}.svg"
      end
    end
  end

  def reorder
    Stage.reset_order(params[:stage_id])
    head :ok
  end

  def clone
    @stage = Stage.build_clone(@stage)
    if request.post?
      @stage.update_attributes! resource_params
      render json: {stage: @stage}
    else
      render :new
    end
  end

  private

  def search_resources
    @project.stages
  end

  def resource_path
    [@project, @stage]
  end

  def resources_path
    @project
  end

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

  def resource_params
    super.permit(stage_permitted_params).merge(project: current_project)
  end

  def set_resource
    if ['new', 'create'].include?(action_name)
      super
    else
      return if assign_resource current_project.stages.find_by_param(params[:id])
      badge? ? head(:not_found) : raise(ActiveRecord::RecordNotFound)
    end
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
