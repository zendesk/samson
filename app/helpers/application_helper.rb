require 'ansible'
require 'github/markdown'

module ApplicationHelper
  include Ansible

  def render_log(str)
    escaped = ERB::Util.html_escape(str)
    ansi_escaped(escaped).gsub(/\[([A-Z]|[0-9]+)m?/, '').html_safe
  end

  def markdown(str)
    GitHub::Markdown.render_gfm(str).html_safe
  end

  def deploy_link(project, stage)
    if stage.currently_deploying?
      content_tag :a, class: "btn btn-primary disabled", disabled: true do
        "Deploying #{stage.current_deploy.short_reference}..."
      end
    elsif stage.locked?
      content_tag :a, class: "btn btn-primary disabled", disabled: true do
        "Locked"
      end
    else
      path = new_project_deploy_path(project, stage_id: stage.id)

      link_to path, role: "button", class: "btn btn-primary" do
        "Deploy"
      end
    end
  end

  def controller_action
    "#{controller_name} #{action_name}"
  end

  def revision
    Rails.application.config.samson.revision.presence
  end

  def global_lock?
    global_lock.present?
  end

  def global_lock
    return @global_lock if defined?(@global_lock)
    @global_lock = Lock.global.first
  end

  def datetime_to_js_ms(utc_string)
    utc_string.to_i * 1000
  end

  def sortable(column, title = nil)
    title ||= column.titleize
    direction = (column == sort_column && sort_direction == "asc") ? "desc" : "asc"
    link_to title, :sort => column, :direction => direction
  end
end
