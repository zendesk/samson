# frozen_string_literal: true
class Admin::DeployGroupsController < ApplicationController
  before_action :authorize_admin!
  before_action :authorize_super_admin!, except: [:index, :show]
  before_action :deploy_group, only: [
    :show, :edit, :update, :destroy,
    :deploy_all, :create_all_stages, :create_all_stages_preview, :delete_all_stages
  ]

  def index
    @deploy_groups = DeployGroup.all.sort_by(&:natural_order)
  end

  def show
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
    missing_only = params[:missing_only] == "true"
    stages_to_deploy = missing_only ? deploy_group.stages.reject(&:last_successful_deploy) : deploy_group.stages
    deploys = stages_to_deploy.map do |stage|
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
    @preexisting_stages, @missing_stages = self.class.stages_for_creation(deploy_group)
  end

  # No more than one stage, per project, per deploy_group
  # Note: you can call this multiple times, and it will create missing stages, but no redundant stages.
  def create_all_stages
    stages_created = self.class.create_all_stages(deploy_group)

    redirect_to [:admin, deploy_group], notice: "Created #{stages_created.length} Stages"
  end

  def merge_all_stages
    render_failures try_each_cloned_stage { |stage| merge_stage(stage) }
  end

  def delete_all_stages
    render_failures try_each_cloned_stage { |stage| delete_stage(stage) }
  end

  def self.create_all_stages(deploy_group)
    _, missing_stages = stages_for_creation(deploy_group)
    missing_stages.map do |template_stage|
      create_stage_with_group(template_stage, deploy_group)
    end
  end

  private

  def render_failures(failures)
    message = failures.map { |reason, stage| "#{stage.project.name} #{stage.name} #{reason}" }.join(", ")

    redirect_to [:admin, deploy_group], alert: (failures.empty? ? nil : "Some stages were skipped: #{message}")
  end

  # executes the block for each cloned stage, returns an array of [result, stage] any non-nil responses.
  def try_each_cloned_stage
    cloned_stages = deploy_group.stages.cloned
    results = cloned_stages.map do |stage|
      result = yield stage
      [result, stage]
    end

    results.select(&:first)
  end

  # returns nil on success, otherwise the reason this stage was skipped.
  def merge_stage(stage)
    template_stage = stage.template_stage

    return "has no template stage to merge into" unless template_stage
    return "is a template stage" if stage.is_template
    return "has no deploy groups" if stage.deploy_groups.count.zero?
    return "has more than one deploy group" if stage.deploy_groups.count > 1
    return "commands in template stage differ" if stage.commands.to_a != template_stage.commands.to_a

    unless template_stage.deploy_groups.include?(stage.deploy_groups.first)
      template_stage.deploy_groups += stage.deploy_groups
      template_stage.save!
    end

    stage.project.stages.reload # need to reload to make verify_not_part_of_pipeline have current data and not fail
    stage.soft_delete!

    nil
  end

  def delete_stage(stage)
    return "has no template stage" unless stage.template_stage
    return "is a template stage" if stage.is_template
    return "has more than one deploy group" if stage.deploy_groups.count > 1
    return "commands in template stage differ" if stage.commands.to_a != stage.template_stage.commands.to_a

    stage.soft_delete!

    nil
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
        deploy_group_stage = deploy_group_stages.detect { |dgs| dgs.project_id == project.id }
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
    (
      [:name, :environment_id, :env_value, :vault_server_id, :permalink] +
      Samson::Hooks.fire(:deploy_group_permitted_params)
    ).freeze
  end

  def deploy_group
    @deploy_group ||= DeployGroup.find_by_param!(params[:id])
  end
end
