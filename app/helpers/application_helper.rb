require 'ansible'

module ApplicationHelper
  include Ansible

  def render_log(str)
    ansi_escaped(str).gsub(/\[([A-Z]|[0-9]+)m?/, '').html_safe
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
end
