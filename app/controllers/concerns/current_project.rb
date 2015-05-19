module CurrentProject
  extend ActiveSupport::Concern

  included do
    helper_method :current_project
  end

  def current_project
    @project
  end

  protected

  def find_project
    @project = Project.find_by_param!(params[:project_id])
  end
end
