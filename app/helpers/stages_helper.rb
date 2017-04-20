# frozen_string_literal: true
module StagesHelper
  def edit_command_link(command)
    edit_url = [:admin, command]
    if command.global?
      link_to "", edit_url, title: "Edit global command", class: "edit-command glyphicon glyphicon-globe no-hover"
    else
      link_to "", edit_url, title: "Edit", class: "edit-command glyphicon glyphicon-edit no-hover"
    end
  end

  def stage_template_icon
    content_tag :span, '',
      class: "glyphicon glyphicon-duplicate",
      title: "Template stage, this stage will be used when copying to new Deploy Groups"
  end
end
