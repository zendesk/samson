require 'coderay'

module DeploysHelper
  def deploy_active?
    @deploy.active? && (JobExecution.find_by_id(@deploy.job_id) || JobExecution.enabled)
  end

  def deploy_page_title
    "#{@deploy.stage.name} deploy (#{@deploy.status}) - #{@project.name}"
  end

  def file_status_label(status)
    mapping = {
      "added"    => "success",
      "modified" => "info",
      "removed"  => "danger"
    }

    type = mapping[status]

    content_tag :span, status[0].upcase, class: "label label-#{type}"
  end

  def file_changes_label(count, type)
    content_tag :span, count.to_s, class: "label label-#{type}" unless count.zero?
  end

  def github_users(users)
    users.map {|user| github_user_avatar(user) }.join(" ").html_safe
  end

  def github_user_avatar(user)
    link_to user.url, title: user.login do
      image_tag user.avatar_url, width: 20, height: 20
    end
  end

  def deploy_status_panel(deploy)
    if BuddyCheck.enabled?
      deploy_status_panel_buddy_check(deploy)
    else
      deploy_status_panel_no_buddy_check(deploy)
    end
  end

  def buddy_check_button(project, deploy)
    return nil unless deploy.waiting_for_buddy?

    button_class = ['btn']

    if @deploy.started_by?(current_user)
      button_text = 'Bypass'
      button_class << 'btn-danger'
    else
      button_text = 'Approve'
      button_class << 'btn-primary'
    end

    link_to button_text, buddy_check_project_deploy_path(@project, @deploy), method: :post, class: button_class.join(' ')
  end

  def duration_text(deploy)
    seconds = 0
    if BuddyCheck.enabled?
      seconds  = deploy.started_at ? (deploy.updated_at - deploy.started_at).to_i : 0
    else
      seconds  = (deploy.updated_at - deploy.created_at).to_i
    end
    duration = ""

    if seconds > 60
      minutes = seconds / 60
      seconds = seconds - minutes * 60

      duration += "#{minutes} minute".pluralize(minutes)
    end

    duration += (seconds > 0 || duration.size == 0 ? " #{seconds} second".pluralize(seconds) : "")
  end

  def syntax_highlight(code, language = :ruby)
    CodeRay.scan(code, language).html.html_safe
  end

  def stages_select_options
    @project.stages.unlocked.map do |stage|
      [stage.name, stage.id, 'data-confirmation' => stage.confirm?]
    end
  end

  private

    # Use when BuddyCheck.enabled? is true
    def deploy_status_panel_buddy_check(deploy)
      mapping = {
        "succeeded" => "success",
        "failed"    => "danger",
        "errored"   => "warning",
        "cancelled" => "danger"
      }

      status = mapping.fetch(deploy.status, "info")

      if deploy.finished?
        content = "#{deploy.summary} "
        content << content_tag(:span, deploy.created_at.rfc822, data: { time: datetime_to_js_ms(deploy.created_at) })
        content << ", it took #{duration_text(deploy)}." if deploy.started_at
        content << (deploy.buddy == deploy.user ?
          " This deploy was bypassed." :
          " This deploy was approved by #{deploy.buddy}.") if deploy.buddy
      elsif deploy.waiting_for_buddy?
        status = "warning"
        content = "This deploy requires a deploy buddy, "
        content << "please have another engineer with deploy rights visit this URL to kick off the deploy."
      else
        content = deploy.summary
      end

      content_tag :div, content.html_safe, class: "alert alert-#{status}"
    end

    # Use when BuddyCheck.enabled? is false
    def deploy_status_panel_no_buddy_check(deploy)
      mapping = {
        "succeeded" => "success",
        "failed"    => "danger",
        "errored"   => "warning",
      }

      status = mapping.fetch(deploy.status, "info")

      if deploy.finished?
        content = "#{deploy.summary} "
        content << content_tag(:span, deploy.created_at.rfc822, data: { time: datetime_to_js_ms(deploy.created_at) })
        content << ", it took #{duration_text(deploy)}."
      else
        content = deploy.summary
      end

      content_tag :div, content.html_safe, class: "alert alert-#{status}"
    end

end
