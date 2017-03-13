# frozen_string_literal: true
require 'ansible'
require 'github/markdown'

module ApplicationHelper
  BOOTSTRAP_FLASH_MAPPINGS = { notice: :info, error: :danger, authorization_error: :danger, success: :success }.freeze

  include Ansible
  include DateTimeHelper

  cattr_reader(:github_status_cache_key) { 'github-status-ok' }

  def render_log(str)
    escaped = ERB::Util.html_escape(str)
    autolink(ansi_escaped(escaped)).html_safe
  end

  # turn exact urls into links so we can follow build urls ... only super simple to stay safe
  def autolink(text)
    text.gsub(%r{https?://[\w:./\d-]+}, %(<a href="\\0">\\0</a>))
  end

  # https://github.com/showdownjs/showdown/wiki/Markdown's-XSS-Vulnerability-(and-how-to-mitigate-it)
  def markdown(str)
    sanitize GitHub::Markdown.render_gfm(str)
  end

  def deploy_link(project, stage)
    if !stage.run_in_parallel && deploy = stage.current_deploy
      link_to "Deploying #{deploy.short_reference}...",
        [project, deploy],
        class: "btn btn-primary"
    elsif Lock.locked_for?(stage, current_user)
      content_tag :a, "Locked", class: "btn btn-primary disabled", disabled: true
    else
      path = new_project_stage_deploy_path(project, stage)
      link_to "Deploy", path, role: "button", class: "btn btn-primary"
    end
  end

  def controller_action
    "#{controller_name} #{action_name}"
  end

  def sortable(column, title = nil)
    title ||= column.titleize
    direction = ((column == params[:sort] && params[:direction] == "asc") ? "desc" : "asc")
    link_to title, sort: column, direction: direction
  end

  def github_ok?
    key = github_status_cache_key

    old = Rails.cache.read(key)
    return old unless old.nil?

    status =
      begin
        status_url = Rails.application.config.samson.github.status_url
        response = Faraday.get("#{status_url}/api/status.json") do |req|
          req.options.timeout = req.options.open_timeout = 1
        end

        response.status == 200 && JSON.parse(response.body)['status'] == 'good'
      rescue Faraday::ClientError
        false
      end

    Rails.cache.write(key, status, expires_in: (status ? 5.minutes : 30.seconds))
    !!status
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

  def icon_tag(type)
    content_tag :i, '', class: "glyphicon glyphicon-#{type}"
  end

  def link_to_delete(path, options = {})
    text = options[:text] || 'Delete'
    disabled_reason = options[:disabled]
    if disabled_reason
      content_tag :span, text, title: disabled_reason, class: 'mouseover'
    else
      resource = Array(path).last
      message =
        if resource.is_a?(ActiveRecord::Base)
          "Delete this #{resource.class.name.split("::").last} ?"
        else
          "Are you sure ?"
        end
      options[:data] = {confirm: message, method: :delete}
      if container = options[:remove_container]
        options[:data][:remove_container] = container
        options[:data][:remote] = true
        options[:class] = "remove_container"
      end
      link_to text, path, options
    end
  end

  def link_to_delete_button(path, options = {})
    link_to_delete(path, options.merge(text: icon_tag('remove') + ' Delete', class: 'btn btn-danger'))
  end

  # Flash type -> Bootstrap alert class
  def flash_messages
    flash.flat_map do |type, messages|
      type = type.to_sym
      bootstrap_class = BOOTSTRAP_FLASH_MAPPINGS[type] || :info
      Array.wrap(messages).map do |message|
        [type, bootstrap_class, message]
      end
    end
  end

  def link_to_url(url)
    link_to(url, url)
  end

  def environments
    @environments ||= Environment.all
  end

  def render_nested_errors(object, seen = Set.new)
    return "" if seen.include?(object)
    seen << object
    return "" if object.errors.empty?

    content_tag :ul do
      lis = object.errors.map do |attribute, message|
        content_tag(:li) do
          content = "".html_safe
          content << object.errors.full_message(attribute, message)
          values = (object.respond_to?(attribute) ? Array.wrap(object.send(attribute)) : [])
          if values.first.is_a?(ActiveRecord::Base)
            values.each do |value|
              content << render_nested_errors(value, seen)
            end
          end
          content
        end
      end
      safe_join lis
    end
  end

  def link_to_history(resource, counter: true)
    return if resource.new_record?
    count = (counter ? " (#{resource.versions.count})" : "")
    link_to "History#{count}", versions_path(item_id: resource.id, item_type: resource.class.name)
  end

  def additional_info(text)
    content_tag :i, '', class: "glyphicon glyphicon-info-sign", title: text
  end

  def page_title(content = nil, in_tab: false, &block)
    content ||= capture(&block)
    content_for :page_title, content
    content_tag((in_tab ? :h2 : :h1), content)
  end

  # keep values short, urls would be ignored ... see application_controller.rb#redirect_back_or
  # also failing fast here for easy debugging instead of sending invalid urls around
  def redirect_to_field
    return unless location = params[:redirect_to].presence || request.referrer.to_s.dup.sub!(root_url, '/')
    hidden_field_tag :redirect_to, location
  end

  def delete_checkbox(form)
    return if form.object.new_record?
    content_tag :div, class: "col-lg-1 checkbox" do
      form.check_box(:_destroy) << form.label(:_destroy, "Delete")
    end
  end
end
