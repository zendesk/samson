# frozen_string_literal: true
class Admin::DeployGroupsController < ApplicationController
  before_action :authorize_admin!
  before_action :authorize_super_admin!, only: [:create, :new, :update, :destroy, :deploy_all,
                                                :create_all_stages, :edit]
  before_action :deploy_group, only: [:show, :edit, :update, :destroy, :deploy_all, :create_all_stages]

  def index
    @deploy_groups = DeployGroup.all.sort_by(&:natural_order)
  end

  def show
  end

  def new
    @deploy_group = DeployGroup.new
    Samson::Hooks.fire(:edit_deploy_group, @deploy_group)
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
    Samson::Hooks.fire(:edit_deploy_group, @deploy_group)
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
    if deploy_group.deploy_groups_stages.empty?
      deploy_group.soft_delete!
      flash[:notice] = "Successfully deleted deploy group: #{deploy_group.name}"
      redirect_to action: :index
    else
      flash[:error] = "Deploy group is still in use."
      redirect_to [:admin, deploy_group]
    end
  end

  def deploy_all
    environment = deploy_group.environment
    deploys = deploy_group.stages.map do |stage|
      template_stage = environment.template_stages.where(project: stage.project).first
      next unless template_stage

      last_success_deploy = template_stage.last_successful_deploy
      next unless last_success_deploy

      deploy_service = DeployService.new(current_user)
      deploy_service.deploy!(stage, reference: last_success_deploy.reference)
    end.compact

    if deploys.empty?
      flash[:error] = "There were no stages ready for deploy."
      redirect_to deploys_path
    else
      redirect_to deploys_path(ids: deploys.map(&:id))
    end
  end

  def create_all_stages
    # No more than one stage, per project, per deploy_group
    # Note: you can call this multiple times, and it will create missing stages, but no redundant stages.
    environment = deploy_group.environment
    Project.where(include_new_deploy_groups: true).each do |project|
      template_stage = environment.template_stages.where(project: project).first
      deploy_group_stage = deploy_group.stages.where(project: project).first
      if template_stage && !deploy_group_stage
        new_stage_with_group(template_stage)
      end
    end
    redirect_to [:admin, deploy_group]
  end

  private

  def new_stage_with_group(stage)
    stage = Stage.build_clone(stage)
    stage.deploy_groups << deploy_group
    stage.name = deploy_group.name
    stage.is_template = false
    stage.save!
    stage
  end

  def deploy_group_params
    params.require(:deploy_group).permit(*allowed_deploy_group_params)
  end

  def allowed_deploy_group_params
    ([:name, :environment_id, :env_value, :vault_instance] + Samson::Hooks.fire(:deploy_group_permitted_params)).freeze
  end

  def deploy_group
    @deploy_group ||= DeployGroup.find_by_param!(params[:id])
  end
end
