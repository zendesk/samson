# frozen_string_literal: true
require 'coderay'

module DeploysHelper
  # maps git changes to bootstrap classes
  GIT_BOOTSTRAP_MAPPINGS = {
    "added"    => "label-success",
    "modified" => "label-info",
    "changed"  => "label-info",
    "removed"  => "label-danger",
    "renamed"  => "label-info"
  }.freeze

  def deploy_output
    output = ActiveSupport::SafeBuffer.new

    if JobExecution.enabled
      output << Samson::Hooks.render_views(:deploy_view, self, deploy: @deploy, project: @project)
    end

    if @deploy.waiting_for_buddy?
      output << render('deploys/buddy_check', deploy: @deploy)
    elsif @deploy.pending?
      output << render('deploys/queued')
    end

    output << render('shared/output', deployable: @deploy, job: @deploy.job, project: @project, hide: @deploy.pending?)
  end

  def deploy_page_title
    "#{@deploy.stage.name} deploy (#{@deploy.status}) - #{@project.name}"
  end

  def deploy_notification
    "Samson deploy finished:\n#{@project.name} / #{@deploy.stage.name} #{@deploy.status}"
  end

  def file_status_label(status)
    label = GIT_BOOTSTRAP_MAPPINGS.fetch(status)
    content_tag :span, status[0].upcase, class: "label #{label}"
  end

  def file_changes_label(count, type)
    content_tag :span, count.to_s, class: "label #{type}" unless count.zero?
  end

  def github_users(github_users)
    github_users.map { |github_user| github_user_avatar(github_user) }.join(" ").html_safe
  end

  def github_user_avatar(github_user)
    return if github_user.nil?

    link_to github_user.url, title: github_user.login do
      image_tag github_user.avatar_url, width: 20, height: 20
    end
  end

  def buddy_check_button(_project, deploy)
    return unless deploy.waiting_for_buddy?

    button_class = ['btn']

    if @deploy.started_by?(current_user)
      button_text = 'Bypass'
      button_class << 'btn-danger'
    else
      button_text = 'Approve'
      button_class << 'btn-primary'
    end

    link_to(
      button_text,
      buddy_check_project_deploy_path(@project, @deploy),
      method: :post, class: button_class.join(' ')
    )
  end

  def syntax_highlight(code, language = :ruby)
    CodeRay.scan(code, language).html.html_safe
  end

  def redeploy_button
    return if @deploy.job.active?

    html_options = {method: :post}
    if @deploy.succeeded?
      html_options[:class] = 'btn btn-default'
      html_options[:data] = {
        toggle: 'tooltip',
        placement: 'auto bottom'
      }
      html_options[:title] = 'Why? This deploy succeeded.'
    else
      html_options[:class] = 'btn btn-danger'
    end

    deploy_params = {reference: @deploy.reference}
    Samson::Hooks.fire(:deploy_permitted_params).flatten(1).each { |p| deploy_params[p] = @deploy.public_send(p) }

    link_to "Redeploy",
      project_stage_deploys_path(
        @project,
        @deploy.stage,
        deploy: deploy_params
      ),
      html_options
  end

  # using project as argument to avoid an additional fetch
  def stop_button(project:, deploy:, **options)
    raise if !project || !deploy
    link_to(
      'Stop',
      [project, deploy, {redirect_to: request.fullpath}],
      options.merge(method: :delete, class: options.fetch(:class, 'btn btn-danger btn-xl'))
    )
  end
end
