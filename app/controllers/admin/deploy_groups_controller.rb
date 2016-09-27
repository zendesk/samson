# frozen_string_literal: true
class Admin::DeployGroupsController < ApplicationController
  before_action :authorize_admin!
  before_action :authorize_super_admin!, only: [:create, :new, :update, :destroy, :deploy_all,
                                                :create_all_stages, :create_all_stages_preview, :edit]
  before_action :deploy_group, only: [:show, :edit, :update, :destroy, :deploy_all, :create_all_stages,
                                      :create_all_stages_preview]

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
    template_stages = environment.template_stages.all
    deploys = deploy_group.stages.map do |stage|
      template_stage = template_stages.detect { |ts| ts.project_id == stage.project.id }
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

  def create_all_stages_preview
    @preexisting_stages, @missing_stages = stages_for_creation
  end

  # No more than one stage, per project, per deploy_group
  # Note: you can call this multiple times, and it will create missing stages, but no redundant stages.
  def create_all_stages
    self.class.create_all_stages(deploy_group)

    redirect_to [:admin, deploy_group]
  end

  def merge_all_stages
    preexisting_stages, = stages_for_creation
    template_stages = deploy_group.environment.template_stages.all

    preexisting_stages.each do |stage|
      template_stage = template_stages.detect { |ts| ts.project_id == stage.project.id }
      merge_stage(stage, template_stage)
    end

    redirect_to [:admin, deploy_group]
  end

  def self.create_all_stages(deploy_group)
    _, missing_stages = stages_for_creation(deploy_group)
    missing_stages.each do |template_stage|
      create_stage_with_group(template_stage, deploy_group)
    end
  end

  private

  def merge_stage(stage, template_stage)
    return unless template_stage
    return if template_stage.deploy_groups.include?(stage.deploy_groups.first)
    return if stage.is_template
    return if stage.deploy_groups.count == 0
    return if stage.deploy_groups.count > 1

    template_stage.deploy_groups += stage.deploy_groups
    template_stage.next_stage_ids.delete(stage.id)
    template_stage.save!

    stage.soft_delete!

    if !stage.reload.deleted?
      Rails.logger.warn("Soft delete of stage #{stage.id} failed")
    end
  end

  def stages_for_creation
    self.class.stages_for_creation(deploy_group)
  end

  class << self
    # returns a list of stages already created and list of stages to create (through their template stages)
    def stages_for_creation(deploy_group)
      environment = deploy_group.environment
      template_stages = environment.template_stages.all
      deploy_group_stages = deploy_group.stages.all

      preexisting_stages = []
      missing_stages = []
      Project.where(include_new_deploy_groups: true).each do |project|
        template_stage = template_stages.detect { |ts| ts.project_id == project.id }
        deploy_group_stage = deploy_group_stages.detect { |dgs| dgs.project.id == project.id }
        if deploy_group_stage
          preexisting_stages << deploy_group_stage
        elsif template_stage
          missing_stages << template_stage
        end
      end

      [preexisting_stages, missing_stages]
    end

    def create_stage_with_group(template_stage, deploy_group)
      stage = Stage.build_clone(template_stage)
      stage.deploy_groups << deploy_group
      stage.name = deploy_group.name
      stage.is_template = false
      stage.save!

      if template_stage.respond_to?(:next_stage_ids) # pipeline plugin was installed
        template_stage.next_stage_ids << stage.id
        template_stage.save!
      end

      stage
    end
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
