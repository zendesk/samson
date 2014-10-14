module StagesHelper
  def edit_command_link(command)
    admin = current_user.is_admin?
    edit_url = edit_admin_command_path(command)
    if command.global?
      title, url = if admin
        ["Edit global command", edit_url]
      else
        ["Global command, can only be edited via Admin UI", "#"]
      end
      link_to "", url, title: title, class: "edit-command glyphicon glyphicon-globe"
    elsif admin
      link_to "", edit_url, title: "Edit in admin UI", class: "edit-command glyphicon glyphicon-edit"
    end
  end
end
