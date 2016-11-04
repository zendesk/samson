# frozen_string_literal: true
module StagesHelper
  def edit_command_link(command)
    admin = current_user.admin? || current_user.admin_for?(command.project)
    edit_url = [:admin, command]
    if command.global?
      title, url =
        if admin
          ["Edit global command", edit_url]
        else
          ["Global command, can only be edited via Admin UI", "#"]
        end
      link_to "", url, title: title, class: "edit-command glyphicon glyphicon-globe no-hover"
    elsif admin
      link_to "", edit_url, title: "Edit in admin UI", class: "edit-command glyphicon glyphicon-edit no-hover"
    end
  end

  def stage_template_icon
    content_tag :span, '',
      class: "glyphicon glyphicon-duplicate",
      title: "Template stage, this stage will be used when copying to new Deploy Groups"
  end
end
