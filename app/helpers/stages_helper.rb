module StagesHelper
  def edit_command_link(command)
    admin = current_user.admin? || current_user.admin_for?(command.project)
    edit_url = edit_admin_command_path(command)
    if command.global?
      title, url = if admin
        ["Edit global command", edit_url]
      else
        ["Global command, can only be edited via Admin UI", "#"]
      end
      link_to "", url, title: title, class: "edit-command glyphicon glyphicon-globe no-hover"
    elsif admin
      link_to "", edit_url, title: "Edit in admin UI", class: "edit-command glyphicon glyphicon-edit no-hover"
    end
  end

  def stage_lock_icon(stage)
    return unless stage.lock
    text = if stage.lock.warning?
      "#{warning_icon} Warning"
    else
      "#{lock_icon} Locked"
    end
    content_tag :span, text.html_safe, class: "label label-warning", title: stage.lock.summary
  end
end
