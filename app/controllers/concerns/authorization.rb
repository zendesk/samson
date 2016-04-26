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
    Rails.logger.warn('Halted as unauthorized! threw :warden')
    throw(:warden) # middleware resolves this into UnauthorizedController
  end
end
