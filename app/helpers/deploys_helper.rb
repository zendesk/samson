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
    output = "".html_safe

    if JobQueue.enabled
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
    "#{@deploy.stage.name} deploy - #{@project.name}"
  end

  def deploy_notification
    "Samson deploy finished:\n#{@deploy.stage.unique_name} #{@deploy.status}"
  end

  def file_status_label(status)
    label = GIT_BOOTSTRAP_MAPPINGS.fetch(status)
    content_tag :span, status[0].upcase, class: "label #{label}"
  end

  def file_changes_label(count, type)
    content_tag :span, count.to_s, class: "label #{type}" unless count == 0
  end

  def github_users(github_users)
    avatars = github_users.map { |github_user| github_user_avatar(github_user) if github_user }
    safe_join avatars, " "
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
      html_options[:title] = 'Previous deploy succeeded.'
    else
      html_options[:class] = 'btn btn-danger'
    end

    link_to "Redeploy",
      project_stage_deploys_path(
        @project,
        @deploy.stage,
        deploy: Samson::RedeployParams.new(@deploy, exact: false).to_hash
      ),
      html_options
  end

  # using project as argument to avoid an additional fetch
  def cancel_button(project:, deploy:, **options)
    raise if !project || !deploy
    link_to(
      'Cancel',
      [project, deploy, {redirect_to: request.fullpath}],
      options.merge(method: :delete, class: options.fetch(:class, 'btn btn-danger btn-xl'))
    )
  end

  def deploy_favicon_path(deploy)
    favicon =
      if deploy.active?
        'favicons/32x32_yellow.png'
      elsif deploy.succeeded?
        'favicons/32x32_green.png'
      else
        'favicons/32x32_red.png'
      end

    path_to_image(favicon)
  end
end
