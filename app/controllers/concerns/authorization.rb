module Authorization
  extend ActiveSupport::Concern

  included do
    helper_method :unauthorized!
    helper_method :authorize_super_admin!
    helper_method :authorize_admin!
  end

  def unauthorized!
    # Eventually to UnauthorizedController
    throw(:warden)
  end

  def authorize_deployer!
    unauthorized! unless current_user.is_deployer?
  end

  def authorize_super_admin!
    unauthorized! unless current_user.is_super_admin?
  end

  def authorize_admin!
    unauthorized! unless current_user.is_admin?
  end
end
