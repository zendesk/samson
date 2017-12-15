# frozen_string_literal: true
module StagesHelper
  def edit_command_link(command)
    title = (command.global? ? "Edit global command" : "Edit")
    icon = (command.global? ? "glyphicon-globe" : "glyphicon-edit")
    link_to "", command, title: title, class: "edit-command glyphicon #{icon} no-hover"
  end

  def stage_template_icon
    icon_tag "duplicate", title: "Template stage, this stage will be used when copying to new Deploy Groups"
  end
end
