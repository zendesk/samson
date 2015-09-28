module HasProjectRole
  extend ActiveSupport::Concern

  def role
    ProjectRole.find(role_id)
  end

  def is_deployer?
    role_id >= ProjectRole::DEPLOYER.id
  end

  def is_admin?
    role_id >= ProjectRole::ADMIN.id
  end

end
