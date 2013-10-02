require 'ansible'

module ApplicationHelper
  include Ansible

  def render_log(str)
    ansi_escaped(str).gsub(/\[([A-Z]|[0-9]+)m?/, '').html_safe
  end
end
