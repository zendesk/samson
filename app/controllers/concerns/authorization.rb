module Authorization
  extend ActiveSupport::Concern

  included do
    helper_method :authorize_super_admin!
    helper_method :authorize_admin!
    helper_method :authorize_deployer!
    helper_method :unauthorized!
  end

  def authorize_super_admin!
    unauthorized! unless current_user.is_super_admin?
  end

  def authorize_admin!
    unauthorized! unless current_user.admin_for?(current_project)
  end

  def authorize_deployer!
    unauthorized! unless current_user.deployer_for?(current_project)
  end

  def unauthorized!
    # Eventually to UnauthorizedController
    throw(:warden)
  end
end
