module CurrentProject
  extend ActiveSupport::Concern

  included do
    helper_method :current_project
  end

  def current_project
    @project
  end

  protected

  def find_project(param)
    # Will this return not found if project does not exist ?
    @project ||= Project.find_by_param!(param)
  end
end
