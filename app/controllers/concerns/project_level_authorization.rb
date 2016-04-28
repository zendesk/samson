module ProjectLevelAuthorization
  extend ActiveSupport::Concern
  include CurrentProject

  private

  def authorize_project_deployer!
    unauthorized! unless current_user.is_deployer_for?(current_project)
  end

  def authorize_project_admin!
    unauthorized! unless current_user.is_admin_for?(current_project)
  end
end
