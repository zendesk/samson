# frozen_string_literal: true
class MassRolloutsController < ApplicationController
  before_action :authorize_deployer!, except: [:new, :create, :merge, :destroy]
  before_action :authorize_super_admin!, except: [:review_deploy, :deploy]
  before_action :deploy_group

  def new
    @preexisting_stages, @missing_stages = stages_for_creation
  end

  # No more than one stage, per project, per deploy_group
  # Note: you can call this multiple times, and it will create missing stages, but no redundant stages.
  # TODO: only create selected list like #deploy does
  def create
    stages_created = create_all_stages.compact

    redirect_to deploy_group, notice: "Created #{stages_created.length} Stages"
  end

  def review_deploy
    if stage_ids = params[:stage_ids]
      @stages = Stage.find(stage_ids)
    else
      @stages = deploy_group.stages.to_a

      case params[:status].presence
      when nil
        # all
      when 'succeeded'
        @stages.select!(&:last_succeeded_deploy)
      when 'missing'
        @stages.reject!(&:last_succeeded_deploy)
      else
        return unsupported_option(:status)
      end

      case params[:kubernetes].to_s.presence
      when nil
        # all
      when 'true'
        @stages.select!(&:kubernetes?)
      when 'false'
        @stages.reject!(&:kubernetes?)
      else
        unsupported_option(:kubernetes)
      end
    end
  end

  def deploy
    warnings = []

    stages = Stage.find(params[:stage_ids] || [])
    deploys = stages.map do |stage|
      reference =
        case params[:reference_source]
        when 'template' then last_successded_template_reference(stage)
        when 'redeploy' then stage.last_succeeded_deploy&.reference
        else return unsupported_option(:reference_source)
        end

      unless reference
        warnings << [stage, "No reference found"]
        next
      end

      deploy = DeployService.new(current_user).deploy(stage, reference: reference)
      if deploy.new_record?
        warnings << [stage, "Validation error"]
        next
      end

      deploy
    end.compact

    # prevent cookie overflow / keep the message short
    ignored = warnings.slice!(10..-1)
    warnings.map! { |stage, message| "#{message} #{stage.url}" }
    warnings << "... #{ignored.size} more" if ignored

    redirect_to(
      deploys_path(ids: deploys.map(&:id).presence),
      alert: helpers.safe_join(warnings, "<br/>".html_safe).presence
    )
  end

  def merge
    render_failures(try_each_cloned_stage { |stage| merge_stage(stage) })
  end

  def destroy
    render_failures(try_each_cloned_stage { |stage| delete_stage(stage) })
  end

  private

  def unsupported_option(option)
    render status: :bad_request, plain: "Unsupported #{option}"
  end

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
    return "has no deploy groups" if stage.deploy_groups.count == 0
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

  def last_successded_template_reference(stage)
    template_stage = deploy_group.environment.template_stages.where(project_id: stage.project_id).first
    template_stage&.last_succeeded_deploy&.reference
  end

  def deploy_group
    @deploy_group ||= DeployGroup.find_by_param!(params[:deploy_group_id])
  end
end
