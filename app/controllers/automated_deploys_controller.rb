# frozen_string_literal: true
# deploys that automatically get triggered when new hosts come up or are restarted
class AutomatedDeploysController < ApplicationController
  before_action :find_or_create_stage
  before_action :find_deploy_group
  before_action :find_last_deploy

  def create
    deploy_service = DeployService.new(current_user)
    env = params.require(:env).to_unsafe_hash.map { |k, v| "export PARAM_#{k}=#{v.gsub("\n", "\\n").shellescape}" }
    env << "export DEPLOY_GROUPS=#{@deploy_group.env_value}"

    deploy = deploy_service.deploy(
      @stage,
      reference: @last_deploy.reference,
      buddy_id: @last_deploy.buddy_id || @last_deploy.job.user_id,
      before_command: env.join("\n") << "\n",
      skip_deploy_group_validation: true
    )

    if deploy.persisted?
      render json: deploy.as_json, status: :created, location: api_deploys_path(deploy)
    else
      failed! "Unable to start deploy: #{deploy.errors.full_messages}"
    end
  end

  private

  def find_or_create_stage
    project = Project.find_by_permalink!(params.require(:project_id))
    @stage = project.stages.where(name: Stage::AUTOMATED_NAME).first || begin
      unless template = project.stages.where(is_template: true).first
        return failed! "Unable to find template for #{project.name}"
      end

      @stage = Stage.build_clone(template)
      @stage.deploy_on_release = false
      @stage.name = Stage::AUTOMATED_NAME
      @stage.dashboard = "Automatically created stage from Api::AutomatedDeploysController<br>" \
        "that will deploy to individual deploy groups or hosts when called via api."

      if command_id = ENV['AUTOMATED_DEPLOY_COMMAND_ID']
        @stage.command_ids = [command_id] + @stage.command_ids
      end

      if email = ENV['AUTOMATED_DEPLOY_FAILURE_EMAIL']
        raise ArgumentError, "email will not work unless user is automated" unless current_user.integration?
        @stage.static_emails_on_automated_deploy_failure = email
      end

      unless @stage.save
        failed!("Unable to save stage: #{@stage.errors.full_messages}")
      end
      @stage
    end
  end

  def find_deploy_group
    @deploy_group = DeployGroup.find_by_permalink!(params.require(:deploy_group))
  end

  def find_last_deploy
    influencing_stages = @deploy_group.pluck_stage_ids
    unless @last_deploy = Deploy.where(project_id: @stage.project_id, stage_id: influencing_stages).succeeded.first
      failed!("Unable to find succeeded deploy for #{@stage.name}")
    end
  end

  def failed!(message)
    render json: {error: message}, status: :bad_request
  end
end
