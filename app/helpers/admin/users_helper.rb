module Admin::UsersHelper

  def project_role_unique_id(user, project)
    project_role = user.project_role_for(project)
    project_role.id unless project_role.nil?
  end

  def role_id_for(user, project)
    project_role = user.project_role_for(project)
    project_role.role_id unless project_role.nil?
  end

end
