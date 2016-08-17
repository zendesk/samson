# frozen_string_literal: true
class Api::StagesController < Api::BaseController
  skip_before_action :require_project, only: :clone

  def index
    render json: current_project.stages
  end

  def clone
    new_stage = Stage.build_clone(stage_to_clone)
    new_stage.name = source_stage[:name]
    new_stage.deploy_groups = deploy_groups if deploy_groups.any?
    if new_stage.save
      render json: new_stage, status: 201
    else
      render json: new_stage.errors, status: 422
    end
  end

  def update
    stage.deploy_groups = deploy_groups
    stage.save!
    head :no_content
  end

  def template_stage
    stage = current_project.template_stage
    if stage
      render json: stage
    else
      render json: { error: "No template stage set." }, status: :not_found
    end
  end

  def mark_template
    current_project.template_stage!(stage)
    head :no_content
  end

  private

  def stage_to_clone
    Stage.find_by_id(params[:stage_id])
  end

  def source_stage
    params.require(:stage).permit(:name, deploy_group_ids: [])
  end

  def deploy_groups
    DeployGroup.where(id: source_stage[:deploy_group_ids])
  end

  def stage
    @project.stages.find(params[:id])
  end
end
