# frozen_string_literal: true
module UsersHelper
  # multiple are checked, but browser only shows last
  def user_project_role_radio(user, project, role_name, role_id)
    global_access = (user.role_id >= role_id.to_i)
    disabled = (user.role_id > role_id.to_i)
    project_access = (user.project_role_for(project).try(:role_id).to_i >= role_id.to_i)
    checked = (global_access || project_access)
    title = "User is a global #{user.role.name.capitalize}" if global_access

    label_tag nil, class: ('disabled' if global_access), title: title do
      radio_button_tag(:role_id, role_id.to_s, checked, disabled: disabled) <<
        " " <<
        role_name.titlecase
    end
  end
end
