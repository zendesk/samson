# frozen_string_literal: true
class DeployGroupsController < ApplicationController
  before_action :authorize_super_admin!, except: [:index, :show, :missing_config]
  before_action :deploy_group, except: [:index, :create, :new]

  def index
    @deploy_groups =
      if project_id = params[:project_id]
        Project.find(project_id).stages.find(params.require(:id)).deploy_groups
      else
        DeployGroup.where(nil)
      end.sort_by(&:natural_order)

    respond_to do |format|
      format.html
      format.json do
        render_as_json(:deploy_groups, @deploy_groups, allowed_includes: Samson::Hooks.fire(:deploy_group_includes))
      end
    end
  end

  def show
    @deployed = Deploy.successful.where(stage_id: @deploy_group.pluck_stage_ids).last_deploys_for_projects
    respond_to do |format|
      format.html
      format.json do
        render json: {
          deploy_group: @deploy_group.as_json,
          deploys: @deployed.as_json,
          projects: @deployed.map(&:project).as_json
        }
      end
    end
  end

  def new
    @deploy_group = DeployGroup.new
    render :edit
  end

  def create
    @deploy_group = DeployGroup.create(deploy_group_params)
    if @deploy_group.persisted?
      flash[:notice] = "Successfully created deploy group: #{@deploy_group.name}"
      redirect_to action: :index
    else
      render :edit
    end
  end

  def edit
  end

  def update
    if deploy_group.update_attributes(deploy_group_params)
      flash[:notice] = "Successfully saved deploy group: #{deploy_group.name}"
      redirect_to action: :index
    else
      render :edit
    end
  end

  def destroy
    if deploy_group.soft_delete(validate: false)
      flash[:notice] = "Successfully deleted deploy group: #{deploy_group.name}"
      redirect_to action: :index
    else
      flash[:error] = "Deploy group could not be deleted because: #{deploy_group.errors.full_messages.join(', ')}"
      redirect_to deploy_group
    end
  end

  def missing_config
    return unless compare = params[:compare].presence
    compare = DeployGroup.find_by_permalink!(compare)

    @diff = Hash.new { |h, k| h[k] = Hash.new { |h, k| h[k] = [] } }

    if missing_secrets = compare_values(compare, deploy_group) { |dg| custom_secrets(dg) }
      missing_secrets.each do |id, s|
        @diff[s.fetch(:project_permalink)]["Secrets"] << id
      end
    end

    if missing_env = compare_values(compare, deploy_group) { |dg| custom_env(dg) }
      missing_env.each do |e|
        project_permalink = (e.parent_type == "Project" ? e.parent.permalink : "global")
        @diff[project_permalink]["Environment"] << e
      end
    end
  end

  private

  def compare_values(a, b)
    a = yield(a)
    b = yield(b)
    return unless missing_keys = (a.keys - b.keys).presence
    a.values_at(*missing_keys)
  end

  def custom_env(deploy_group)
    supported = [Project.name, EnvironmentVariableGroup.name]
    EnvironmentVariable.where(scope: deploy_group, parent_type: supported).each_with_object({}) do |e, h|
      h[[e.name, e.parent_type, e.parent_id]] = e
    end
  end

  def custom_secrets(deploy_group)
    Samson::Secrets::Manager.lookup_cache.each_with_object({}) do |(id, _), h|
      parts = Samson::Secrets::Manager.parse_id(id)
      next unless parts.fetch(:deploy_group_permalink) == deploy_group.permalink
      h[parts.except(:deploy_group_permalink)] = [id, parts]
    end
  end

  def deploy_group_params
    params.require(:deploy_group).permit(*allowed_deploy_group_params)
  end

  def allowed_deploy_group_params
    (
      [:name, :environment_id, :env_value, :vault_server_id, :permalink] +
      Samson::Hooks.fire(:deploy_group_permitted_params)
    ).freeze
  end

  def deploy_group
    @deploy_group ||= DeployGroup.find_by_param!(params[:id])
  end
end
