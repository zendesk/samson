module ProjectLevelAuthorization
  extend ActiveSupport::Concern

  include Authorization
  include CurrentProject

  included do
    helper_method :authorize_project_admin!
    helper_method :authorize_project_deployer!
  end

  def authorize_project_deployer!
    unauthorized! unless current_user.is_deployer? || current_user.is_deployer_for?(current_project)
  end

  def authorize_project_admin!
    unauthorized! unless current_user.is_admin? || current_user.is_admin_for?(current_project)
  end
end
