# frozen_string_literal: true
require 'ansible'
require 'github/markdown'

module ApplicationHelper
  BOOTSTRAP_FLASH_MAPPINGS = {notice: :info, error: :danger, authorization_error: :danger, success: :success}.freeze
  BOOTSTRAP_TOOLTIP_PROPS = {toggle: 'popover', placement: 'right', trigger: 'hover'}.freeze

  include Ansible
  include DateTimeHelper
  include Pagy::Frontend

  def render_log(str)
    escaped = ERB::Util.html_escape(str)
    autolink(ansi_escaped(escaped)).html_safe
  end

  # turn exact urls into links so we can follow build urls ... only super simple to stay safe
  def autolink(text)
    text.gsub(%r{https?://[\w:@./\d#?&=-]+}, %(<a href="\\0">\\0</a>))
  end

  # https://github.com/showdownjs/showdown/wiki/Markdown's-XSS-Vulnerability-(and-how-to-mitigate-it)
  def markdown(str)
    sanitize GitHub::Markdown.render_gfm(str)
  end

  def deploy_link(project, stage)
    if !stage.run_in_parallel && deploy = stage.active_deploy
      link_to "Deploying #{deploy.short_reference}...",
        [project, deploy],
        class: "btn btn-primary"
    elsif Lock.locked_for?(stage, current_user)
      content_tag :a, "Locked", class: "btn btn-primary disabled", disabled: true
    elsif stage.direct?
      path = project_stage_deploys_path(
        project, stage, deploy: {reference: stage.default_reference.presence || "master", stage_id: stage.id}
      )
      link_to "Deploy", path, role: "button", class: "btn btn-warning", data: {method: :post}
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

  def breadcrumb(*items)
    items = items.map do |item|
      if item.is_a?(ActiveRecord::Base)
        link_parts_for_resource(item)
      else
        case item
        when String then [item, nil]
        when Array then item
        else
          raise ArgumentError, "Unsupported breadcrumb for #{item}"
        end
      end
    end
    manual_breadcrumb(items)
  end

  # tested via link_to_resource
  def link_parts_for_resource(resource)
    case resource
    when Project, DeployGroup, User, Samson::Secrets::VaultServer then [resource.name, resource]
    when Command then ["Command ##{resource.id}", resource]
    when UserProjectRole then ["Role for ##{resource.user.name}", resource.user]
    when Environment then [resource.name, dashboard_path(resource)]
    when Stage then
      name = resource.name
      name = (resource.lock.warning? ? warning_icon : lock_icon) + " " + name if resource.lock
      [name, [resource.project, resource]]
    when Deploy then ["Deploy ##{resource.id}", [resource.project, resource]]
    when SecretSharingGrant then [resource.key, resource]
    else
      @@link_parts_for_resource ||= Samson::Hooks.fire(:link_parts_for_resource).to_h
      proc = @@link_parts_for_resource[resource.class.name] ||
        raise(ArgumentError, "Unsupported resource #{resource.class.name}")
      proc.call(resource)
    end
  end

  def link_to_resource(resource)
    name, path = link_parts_for_resource(resource)
    if Array(path).any?(&:nil?)
      name
    else
      link_to(name, path)
    end
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

  def audited_classes
    @@audited_classes ||= begin
      if !Rails.application.config.eager_load || Rails.env.test? # need coverage in test
        # load all models so we can find out who is audited ... require would add warnings because of rails autoload
        folders = Samson::Hooks.plugins.map(&:folder) << File.expand_path(".") # all gems and root
        Dir["{#{folders.join(",")}}/app/models/**/*.rb"].reject { |f| f.include?("/concerns/") }.each do |f|
          f.split("/app/models/").last.sub(".rb", "").camelize.constantize
        end
      end
      ActiveRecord::Base.send(:descendants).select { |d| d.respond_to?(:audited_options) }.map(&:name)
    end
  end

  def icon_tag(type, options = {})
    css_classes = "glyphicon glyphicon-#{type}"

    if klass = options[:class]
      css_classes += " #{klass}"
    end

    content_tag :i, '', options.merge(class: css_classes)
  end

  def link_to_delete(path, options = {})
    text = options[:text] || 'Delete'
    disabled_reason = options[:disabled]
    if disabled_reason
      content_tag :span, text, title: disabled_reason, class: 'mouseover'
    else
      resource = Array(path).last
      message =
        if question = options.delete(:question)
          question
        elsif resource.is_a?(ActiveRecord::Base)
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
    count = (counter ? " (#{resource.audits.count})" : "")
    link_to "History#{count}", audits_path(search: {auditable_id: resource.id, auditable_type: resource.class.name})
  end

  def additional_info(text, overrides = {})
    data_attrs = if text.html_safe?
      {content: ERB::Util.h(ERB::Util.h(text).to_str), html: true}
    else
      {content: text}
    end.merge(BOOTSTRAP_TOOLTIP_PROPS)

    options = {class: 'glyphicon glyphicon-info-sign'}.merge(overrides)

    content_tag :i, '', **options, data: data_attrs
  end

  def page_title(content = nil, in_tab: false, &block)
    content ||= capture(&block)
    title_content = content
    title_content += " - #{@project.name}" if @project
    title_content = strip_tags(title_content).gsub('&amp;', '&').html_safe
    content_for :page_title, title_content
    content_tag((in_tab ? :h2 : :h1), content)
  end

  # keep values short, urls would be ignored ... see application_controller.rb#redirect_back
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

  def search_form(options = {}, &block)
    form_tag '?', options.merge(method: :get, class: "clearfix") do
      button = submit_tag("Search", class: "btn btn-default form-control", style: "margin-top: 25px")
      capture(&block) << content_tag(:div, button, class: "col-md-1 clearfix")
    end
  end

  def search_select(
    column, values,
    live: false, size: 2, label: column.to_s.humanize, selected: params.dig(:search, column), title: nil
  )
    options = (live ? Samson::FormBuilder::LIVE_SELECT_OPTIONS.dup : {class: "form-control"})
    options[:include_blank] = true

    content_tag :div, class: "col-sm-#{size}", title: title do
      label_tag(label) << select_tag("search[#{column}]", options_for_select(values, selected), options)
    end
  end

  def live_select_tag(name, values, options = {})
    select_tag name, values, Samson::FormBuilder::LIVE_SELECT_OPTIONS.merge(options)
  end

  def paginate(pagy)
    multi_page = pagy.pages > 1
    result = (multi_page ? pagy_nav_bootstrap(pagy) : "").html_safe
    if multi_page
      result << content_tag(:span, " #{pagy.count} records", style: "padding: 10px")
    end
    result
  end

  def unordered_list(items, display_limit: nil, show_more_tag: nil, ul_options: {}, li_options: {}, &block)
    shown_items = items.first(display_limit || items.size)
    li_tags = shown_items.map { |item| content_tag(:li, nil, li_options) { capture(item, &block) } }
    li_tags << show_more_tag if display_limit && items.size > display_limit

    content_tag(:ul, safe_join(li_tags), ul_options)
  end

  # See https://developers.google.com/chart/image/docs/chart_params
  def link_to_chart(name, values)
    return if values.size < 3

    max = values.max.round
    y_axis = [0, max / 4, max / 2, (max / 1.333333).to_i, max].map { |t| duration_text(t) }.join("|")
    y_values = values.reverse.map { |v| max == 0 ? max : (v * 100.0 / max).round }.join(",") # values as % of max
    params = {
      cht: "lc", # chart type
      chtt: name,
      chd: "t:#{y_values}", # data
      chxt: "y", # axis to draw
      chxl: "0:|#{y_axis}", # axis labels
      chs: "1000x200", # size
    }
    url = "https://chart.googleapis.com/chart?#{params.to_query}"
    link_to icon_tag('signal'), url, target: :blank
  end

  # show which stages this reference is deploy(ed+ing) to
  def deployed_or_running_list(stages, reference)
    html = "".html_safe
    stages.each do |stage|
      next unless deploy = stage.deployed_or_running_deploy
      next unless deploy.references?(reference)
      label = (deploy.active? ? "label-warning" : "label-success")

      text = "".html_safe
      text << stage.name
      html << content_tag(:span, text, class: "label #{label} release-stage")
      html << " "
    end
    html
  end

  def github_user_avatar(github_user)
    image_tag github_user.avatar_url,
      title: github_user.login,
      class: "gravatar github-user-avatar",
      width: 20,
      height: 20,
      'data-toggle': "tooltip"
  end

  def check_box_section(section_title, help_text, object, method, collection)
    content_tag(:fieldset) do
      result = ''.html_safe

      result << content_tag(:legend, section_title)
      result << content_tag(:p, help_text, class: 'col-lg-offset-2')
      result << content_tag(:div, class: 'col-lg-4 col-lg-offset-2') do
        check_boxes = ''.html_safe
        check_boxes << collection_check_boxes(object, method, collection, :id, :name) do |b|
          box = ''.html_safe
          box << b.check_box + ' '
          box << b.label
          box << tag(:br)
        end
      end
    end
  end
end
