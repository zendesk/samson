module Admin::UsersHelper

  def can_modify_roles?
    current_user.is_super_admin?
  end

end
