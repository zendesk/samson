# frozen_string_literal: true
module StatusHelper
  ALERT_STATUS_MAPPING = {
    "succeeded" => "success",
    "failed" => "danger",
    "errored" => "danger",
    "cancelling" => "warning",
    "cancelled" => "danger"
  }.freeze

  LABEL_STATUS_MAPPING = ALERT_STATUS_MAPPING.merge(
    "running" => "primary"
  )

  def status_alert(key)
    "alert-#{ALERT_STATUS_MAPPING.fetch(key, 'info')}"
  end

  def status_label(key)
    "label-#{LABEL_STATUS_MAPPING.fetch(key, 'info')}"
  end

  def status_panel(deploy)
    content = h deploy.summary
    if deploy.active?
      content << content_tag(:br)
      content << "Started "
      content << relative_time(deploy.start_time)
      job = deploy.respond_to?(:job) ? deploy.job : deploy
      content << " [Process ID: #{job.pid}]"
    end

    if deploy.finished?
      content << " "
      content << render_time(deploy.start_time, current_user.time_format)
      content << ", it took #{duration_text(deploy)}."
    end

    content_tag :div, content.html_safe, class: "alert #{status_alert(deploy.status)}"
  end

  def duration_text(deploy)
    seconds  = (deploy.updated_at - deploy.start_time).to_i

    duration = "".dup

    if seconds > 60
      minutes = seconds / 60
      seconds -= minutes * 60

      duration << "#{minutes} minute".pluralize(minutes)
    end

    duration << (seconds > 0 || duration.empty? ? " #{seconds} second".pluralize(seconds) : "")
  end
end
