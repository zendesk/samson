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

  def deploy_link(project, options = {})
    path = new_project_deploy_path(project, options)

    link_to path, role: "button", class: "btn btn-danger" do
      concat content_tag :span, "", class: "glyphicon glyphicon-play"
      concat " Deploy!"
    end
  end

  def controller_action
    "#{controller_name} #{action_name}"
  end

  def revision
    Rails.application.config.pusher.revision.presence
  end
end
