module Admin::UsersHelper

  def project_role_id_for(user, project)
    user.project_role_for(project).try(:id)
  end

  def role_id_for(user, project)
    user.project_role_for(project).try(:role_id)
  end

end
