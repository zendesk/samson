# frozen_string_literal: true
module CurrentStage
  extend ActiveSupport::Concern

  included do
    before_action :require_stage
    helper_method :current_stage
  end

  def current_stage
    @stage
  end

  protected

  def require_stage
    return unless current_project
    return unless stage_param = params[:stage_id] || params[:id]
    @stage = Stage.where(project_id: current_project.id).find_by_param!(stage_param)
  end
end
