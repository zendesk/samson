require 'ansible'
require 'github/markdown'

module ApplicationHelper
  include Ansible

  cattr_reader(:github_status_cache_key) { 'github-status-ok' }

  def render_log(str)
    escaped = ERB::Util.html_escape(str)
    ansi_escaped(escaped).gsub(/\[([A-Z]|[0-9]+)m?/, '').html_safe
  end

  def markdown(str)
    GitHub::Markdown.render_gfm(str).html_safe
  end

  def deploy_link(project, stage)
    if deploy = stage.current_deploy
      link_to "Deploying #{deploy.short_reference}...",
        [project, deploy],
        class: "btn btn-primary"
    elsif stage.locked_for?(current_user)
      content_tag :a, "Locked", class: "btn btn-primary disabled", disabled: true
    else
      path = new_project_stage_deploy_path(project, stage)
      link_to "Deploy", path, role: "button", class: "btn btn-primary"
    end
  end

  def controller_action
    "#{controller_name} #{action_name}"
  end

  def revision
    Rails.application.config.samson.revision.presence
  end

  def global_lock
    return @global_lock if defined?(@global_lock)
    @global_lock = Lock.global.first
  end

  def render_global_lock
    render '/locks/lock', lock: global_lock if global_lock
  end

  def relative_time(time)
    content_tag(:span, time.rfc822, data: { time: datetime_to_js_ms(time) }, class: "mouseover")
  end

  def datetime_to_js_ms(utc_string)
    utc_string.to_i * 1000
  end

  def sortable(column, title = nil)
    title ||= column.titleize
    direction = (column == params[:sort] && params[:direction] == "asc") ? "desc" : "asc"
    link_to title, sort: column, direction: direction
  end

  def github_ok?
    status_url = Rails.application.config.samson.github.status_url

    Rails.cache.fetch(github_status_cache_key, expires_in: 5.minutes) do
      response = Faraday.get("https://#{status_url}/api/status.json") do |req|
        req.options.timeout = req.options.open_timeout = 1
      end

      # don't cache bad responses
      (response.status == 200 && JSON.parse(response.body)['status'] == 'good') || nil
    end
  rescue Faraday::ClientError
    false
  end

  def breadcrumb(*items)
    items = items.map do |item|
      case item
      when Project then [item.name, project_path(item)]
      when Environment then [item.name, dashboard_path(item)]
      when DeployGroup then [item.name, deploy_group_path(item)]
      when Stage then
        name = item.name
        name = (item.lock.warning? ? warning_icon : lock_icon) + " " + name if item.lock
        [name, project_stage_path(item.project, item)]
      when Macro then
        [item.name, project_macro_path(item.project, item)]
      when String then [item, nil]
      when Build then [item.nice_name, project_build_path(item)]
      when Array then item
      else
        raise "Unsupported breadcrumb for #{item}"
      end
    end
    manual_breadcrumb(items)
  end

  def manual_breadcrumb(items)
    items.unshift ["Home", root_path]
    items.last << true # mark last as active

    content_tag :ul, class: "breadcrumb" do
      items.each.map do |name, url, active|
        content = (active ? name : link_to(name, url))
        content_tag :li, content, class: (active ? "active" : "")
      end.join.html_safe
    end
  end

  def lock_icon
    icon_tag "lock"
  end

  def warning_icon
    icon_tag "warning-sign"
  end

  def icon_tag(type)
    content_tag :i, '', class: "glyphicon glyphicon-#{type}"
  end

  def link_to_delete(path, body = 'Delete', options={})
    link_to body, path, options.merge({ method: :delete, data: { confirm: "Are you sure?" } })
  end

  def link_to_delete_button(path)
    link_to_delete(path, icon_tag('remove') + ' Delete', class: 'btn btn-danger')
  end
end
