class Admin::DeployGroupsController < ApplicationController
  before_action :authorize_admin!
  before_action :authorize_super_admin!, only: [ :create, :new, :update, :destroy, :deploy_all, :deploy_all_now ]
  before_action :deploy_group, only: [:show, :edit, :update, :destroy, :deploy_all, :deploy_all_now]

  def index
    @deploy_groups = DeployGroup.all.sort_by(&:natural_order)
  end

  def new
    @deploy_group = DeployGroup.new
    Samson::Hooks.fire(:edit_deploy_group, @deploy_group)
    render 'edit'
  end

  def create
    @deploy_group = DeployGroup.create(deploy_group_params)
    if @deploy_group.persisted?
      flash[:notice] = "Successfully created deploy group: #{@deploy_group.name}"
      redirect_to action: 'index'
    else
      flash[:error] = @deploy_group.errors.full_messages
      render 'edit'
    end
  end

  def edit
    Samson::Hooks.fire(:edit_deploy_group, @deploy_group)
  end

  def update
    if deploy_group.update_attributes(deploy_group_params)
      flash[:notice] = "Successfully saved deploy group: #{deploy_group.name}"
      redirect_to action: 'index'
    else
      flash[:error] = deploy_group.errors.full_messages
      render 'edit'
    end
  end

  def destroy
    deploy_group.soft_delete!
    flash[:notice] = "Successfully deleted deploy group: #{deploy_group.name}"
    redirect_to action: 'index'
  end

  def deploy_all
    @stages = Project.all.flat_map do |project|
      environment = Environment.find(params[:environment_id]) if params[:environment_id]

      stages = stages_in_same_environment(project, environment)
      next unless deploy = stages.map(&:last_successful_deploy).compact.sort_by(&:created_at).last
      stages.map { |s| [s, deploy] }
    end.compact
  end

  def deploy_all_now
    deploys = params.require(:stages).map do |stage|
      stage_id, reference = stage.split("-", 2)
      stage = Stage.find(stage_id)
      stage = new_stage_with_group(stage) unless only_to_current_group?(stage)
      deploy_service = DeployService.new(current_user)
      deploy_service.deploy!(stage, reference: reference)
    end
    redirect_to deploys_path(ids: deploys.map(&:id))
  end

  private

  def only_to_current_group?(stage)
    stage.deploy_groups.map(&:id) == [deploy_group.id]
  end

  def stages_in_same_environment(project, environment)
    project.stages.without_macros.select do |stage|
      stage.command.include?("$DEPLOY_GROUPS") && # is dynamic
        stage.deploy_groups.where(environment: environment || deploy_group.environment).exists? # is made to go to this environment
    end.sort_by { |stage| only_to_current_group?(stage) ? 0 : 1 }
  end

  def new_stage_with_group(stage)
    stage = Stage.build_clone(stage)
    stage.deploy_groups << deploy_group
    stage.name = deploy_group.name
    stage.name << " -- copy #{SecureRandom.hex(4)}" if stage.project.stages.where(name: stage.name).exists?
    stage.save!
    stage
  end

  def deploy_group_params
    params.require(:deploy_group).permit(*allowed_deploy_group_params)
  end

  def allowed_deploy_group_params
    ([:name, :environment_id, :env_value] + Samson::Hooks.fire(:deploy_group_permitted_params)).freeze
  end

  def deploy_group
    @deploy_group ||= DeployGroup.find_by_param!(params[:id])
  end
end
