module Authorization
  private

  def authorize_super_admin!
    unauthorized! unless current_user.is_super_admin?
  end

  def authorize_admin!
    unauthorized! unless current_user.is_admin?
  end

  def authorize_deployer!
    unauthorized! unless current_user.is_deployer?
  end

  def unauthorized!
    # Eventually to UnauthorizedController
    throw(:warden)
  end
end
