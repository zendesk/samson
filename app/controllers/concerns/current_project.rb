# frozen_string_literal: true
module CurrentProject
  extend ActiveSupport::Concern

  included do
    before_action :require_project
    helper_method :current_project
  end

  protected

  def current_project
    @project
  end

  def require_project
    @project = (Project.find_by_param!(params[:project_id]) if params[:project_id])
  end
end
