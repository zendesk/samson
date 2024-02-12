# frozen_string_literal: true
class Kubernetes::DeployGroupRolesController < ResourceController
  include CurrentProject

  before_action :authorize_project_admin!, except: [:index, :show, :new]
  before_action :set_resource, only: [:show, :edit, :update, :destroy, :new, :create]
  before_action :find_stage, only: [:seed]

  def index
    if params[:project_id] && request.format.html? # sorted/complete but slow display on project tab
      super resources: sorted_resources, paginate: false
    else
      super
      preload_deleted_deploy_groups @kubernetes_deploy_group_roles
    end
  end

  def edit_many
    @kubernetes_deploy_group_roles = sorted_resources
  end

  def update_many
    @kubernetes_deploy_group_roles = sorted_resources

    all_params = params.require(:kubernetes_deploy_group_roles)
    status = @kubernetes_deploy_group_roles.map do |deploy_group_role|
      role_params = all_params.require(deploy_group_role.id.to_s).permit(permitted_params)
      deploy_group_role.update(role_params)
    end

    if status.all?
      redirect_to project_kubernetes_deploy_group_roles_path(@project), notice: "Updated!"
    else
      render :edit_many
    end
  end

  def seed
    created = ::Kubernetes::DeployGroupRole.seed!(@stage)
    options =
      if created.all?(&:persisted?)
        {notice: "Missing roles seeded."}
      else
        errors = ["Roles failed to seed, fill them in manually."]
        errors.concat(
          created.map do |dgr|
            "#{dgr.kubernetes_role.name} for #{dgr.deploy_group.name}: #{dgr.errors.full_messages.to_sentence}"
          end
        )
        max = 4 # header + 3
        message = errors.first(max).join("\n")
        message << " ..." if errors.size > max
        {alert: view_context.simple_format(message)}
      end
    redirect_to [@stage.project, @stage], options
  end

  private

  def preload_deleted_deploy_groups(deploy_group_roles)
    DeployGroup.with_deleted { deploy_group_roles.each(&:deploy_group) }
  end

  def sorted_resources
    preload_deleted_deploy_groups(search_resources).
      sort_by { |dgr| [dgr.project.name, dgr.kubernetes_role.name, dgr.deploy_group&.name_sortable.to_s] }
  end

  def search_resources
    # treat project/foo/roles the same as a search
    if params[:project_id]
      params[:search] ||= {}
      params[:search][:project_id] = current_project.id
    end

    deploy_group_roles = ::Kubernetes::DeployGroupRole.all
    [:project_id, :deploy_group_id].each do |scope|
      if id = params.dig(:search, scope).presence
        deploy_group_roles = deploy_group_roles.where(scope => id)
      end
    end

    deploy_group_roles
  end

  def find_stage
    @stage = Stage.find(params.require(:stage_id))
  end

  def resource_params
    super.permit(*permitted_params).merge(project: @project)
  end

  def permitted_params
    allowed = [
      :requests_memory, :requests_cpu, :limits_memory, :limits_cpu,
      :replicas, :delete_resource, :inject_istio_annotation
    ]
    allowed.concat [:deploy_group_id, :kubernetes_role_id] if ["new", "create"].include?(action_name)
    allowed << :no_cpu_limit if Kubernetes::DeployGroupRole::NO_CPU_LIMIT_ALLOWED
    allowed
  end

  def resource_path
    [@project, @resource]
  end
end
