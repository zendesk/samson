# frozen_string_literal: true
class MassRolloutsController < ApplicationController
  before_action :authorize_super_admin!
  before_action :deploy_group

  def new
    @preexisting_stages, @missing_stages = stages_for_creation
  end

  # No more than one stage, per project, per deploy_group
  # Note: you can call this multiple times, and it will create missing stages, but no redundant stages.
  def create
    stages_created = create_all_stages.compact

    redirect_to deploy_group, notice: "Created #{stages_created.length} Stages"
  end

  def deploy
    successful, missing = deploy_group.stages.partition(&:last_successful_deploy)
    stages_to_deploy = []

    stages_to_deploy += successful if params[:successful] == "true"
    stages_to_deploy += missing if params[:missing] == "true"

    if defined?(SamsonKubernetes::Engine)
      stages_to_deploy.reject!(&:kubernetes?) if params[:kubernetes] != "true"
      stages_to_deploy.select!(&:kubernetes?) if params[:non_kubernetes] != "true"
    end

    deploy_references = stages_to_deploy.map do |stage|
      reference = get_reference_from_template_stage(stage)
      [stage, reference] if reference
    end.compact

    deploys = deploy_references.map do |stage, reference|
      deploy_service = DeployService.new(current_user)
      deploy_service.deploy(stage, reference: reference)
    end

    if deploys.empty?
      flash[:error] = "There were no stages that matched the mass rollout deploy criteria."
      redirect_to deploys_path
    else
      redirect_to deploys_path(ids: deploys.map(&:id))
    end
  end

  def merge
    render_failures(try_each_cloned_stage { |stage| merge_stage(stage) })
  end

  def destroy
    render_failures(try_each_cloned_stage { |stage| delete_stage(stage) })
  end

  private

  def create_all_stages
    _, missing_stages = stages_for_creation
    missing_stages.map do |template_stage|
      begin
        create_stage_with_group template_stage
      rescue StandardError => e
        Rails.logger.error("Failed to create new stage from template #{template_stage.unique_name}.\n#{e.message}")
        nil
      end
    end
  end

  def render_failures(failures)
    message = failures.map { |reason, stage| "#{stage.project.name} #{stage.name} #{reason}" }.join(", ")

    redirect_to deploy_group, alert: (failures.empty? ? nil : "Some stages were skipped: #{message}")
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
    return "commands in template stage differ" if stage.script != template_stage.script

    unless template_stage.deploy_groups.include?(stage.deploy_groups.first)
      template_stage.deploy_groups += stage.deploy_groups
      template_stage.save!
    end

    stage.project.stages.reload # need to reload to make verify_not_part_of_pipeline have current data and not fail
    stage.soft_delete!(validate: false)

    nil
  end

  def delete_stage(stage)
    return "has no template stage" unless stage.template_stage
    return "is a template stage" if stage.is_template
    return "has more than one deploy group" if stage.deploy_groups.count > 1
    return "commands in template stage differ" if stage.script != stage.template_stage.script

    stage.soft_delete!(validate: false)

    nil
  end

  # returns a list of stages already created and list of stages to create (through their template stages)
  def stages_for_creation
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

  def create_stage_with_group(template_stage)
    stage = Stage.build_clone(
      template_stage,
      deploy_groups: [deploy_group],
      name: deploy_group.name
    )

    stage.save!

    if template_stage.respond_to?(:next_stage_ids) # pipeline plugin was installed
      template_stage.next_stage_ids << stage.id
      template_stage.save!
    end

    stage
  end

  def get_reference_from_template_stage(stage)
    template_stage = deploy_group.environment.template_stages.find_by(project_id: stage.project_id)
    template_stage&.last_successful_deploy&.reference
  end

  def deploy_group
    @deploy_group ||= DeployGroup.find_by_param!(params[:deploy_group_id])
  end
end
