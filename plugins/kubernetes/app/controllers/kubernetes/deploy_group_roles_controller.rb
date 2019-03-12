# frozen_string_literal: true
class Kubernetes::DeployGroupRolesController < ResourceController
  before_action :set_resource, only: [:show, :edit, :update, :destroy, :new, :create]
  before_action :find_roles, only: [:index, :edit_many, :update_many]
  before_action :find_stage, only: [:seed]
  before_action :authorize_project_admin!, except: [:index, :show, :new]

  DEFAULT_BRANCH = "master"

  # TODO: use super
  def index
    respond_to do |format|
      format.html
      format.json { render json: {kubernetes_deploy_group_roles: @deploy_group_roles} }
    end
  end

  # TODO: use super
  def show
    respond_to do |format|
      format.html
      format.json do
        deploy_group_role = @kubernetes_deploy_group_role.as_json
        if params[:include].to_s.split(',').include?("verification_template")
          deploy_group_role[:verification_template] = verification_template.to_hash(verification: true)
        end

        render json: {
          kubernetes_deploy_group_role: deploy_group_role
        }
      end
    end
  end

  def edit_many
  end

  def update_many
    all_params = params.require(:kubernetes_deploy_group_roles)
    status = @deploy_group_roles.map do |deploy_group_role|
      role_params = all_params.require(deploy_group_role.id.to_s).permit(permitted_params)
      deploy_group_role.update_attributes(role_params)
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
        errors.concat(created.map do |dgr|
          "#{dgr.kubernetes_role.name} for #{dgr.deploy_group.name}: #{dgr.errors.full_messages.to_sentence}"
        end)
        max = 4 # header + 3
        message = errors.first(max).join("\n")
        message << " ..." if errors.size > max
        {alert: view_context.simple_format(message)}
      end
    redirect_to [@stage.project, @stage], options
  end

  private

  def find_roles
    # treat project/foo/roles the same as a search
    if params[:project_id]
      params[:search] ||= {}
      params[:search][:project_id] = current_project.id
    end

    deploy_group_roles = ::Kubernetes::DeployGroupRole.where(nil)
    [:project_id, :deploy_group_id].each do |scope|
      if id = params.dig(:search, scope).presence
        deploy_group_roles = deploy_group_roles.where(scope => id)
      end
    end

    # TODO: needs to return something paginatable and not rely on with_deleted
    @deploy_group_roles = DeployGroup.with_deleted do
      deploy_group_roles.
        sort_by { |dgr| [dgr.project.name, dgr.kubernetes_role.name, dgr.deploy_group&.name_sortable].compact }
    end
  end

  def verification_template
    role = @kubernetes_deploy_group_role
    project = role.project

    # find ref and sha ... sha takes priority since it's most accurate
    git_sha = params[:git_sha]
    git_ref = params[:git_ref] || git_sha || DEFAULT_BRANCH
    git_sha ||= project.repository.commit_from_ref(git_ref)

    release = Kubernetes::Release.new(
      git_ref: git_ref,
      git_sha: git_sha,
      project: project,
      user: current_user,
      builds: [],
      deploy_groups: [role.deploy_group]
    )
    release_doc = Kubernetes::ReleaseDoc.new(
      kubernetes_release: release,
      kubernetes_role: role.kubernetes_role,
      deploy_group: role.deploy_group,
      requests_cpu: role.requests_cpu,
      limits_cpu: role.limits_cpu,
      requests_memory: role.requests_memory,
      limits_memory: role.limits_memory,
      replica_target: role.replicas
    )

    release_doc.verification_template
  end

  def find_stage
    @stage = Stage.find(params.require(:stage_id))
  end

  def current_project
    @project ||= # rubocop:disable Naming/MemoizedInstanceVariableName
      if action_name == 'create'
        Project.find(resource_params.require(:project_id))
      elsif action_name == 'seed'
        @stage.project
      elsif ['index', 'edit_many', 'update_many'].include?(action_name)
        Project.find_by_param!(params.require(:project_id))
      else
        @kubernetes_deploy_group_role.project
      end
  end

  def resource_params
    super.permit(*permitted_params)
  end

  def permitted_params
    allowed = [
      :requests_memory, :requests_cpu, :limits_memory, :limits_cpu,
      :replicas, :delete_resource
    ]
    allowed.concat [:project_id, :deploy_group_id, :kubernetes_role_id] if ["new", "create"].include?(action_name)
    allowed << :no_cpu_limit if Kubernetes::DeployGroupRole::NO_CPU_LIMIT_ALLOWED
    allowed
  end
end
