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
    if current_project
      query = Stage.where(project_id: current_project.id)
      stage_param = params[:stage_id] || params[:id]
      @stage = query.find_by_param!(stage_param) if stage_param
    end
  end
end
