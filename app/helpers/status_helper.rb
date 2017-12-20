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

  def status_badge(status)
    content_tag :span, status.titleize, class: "label #{status_label(status)}"
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
      job = (deploy.respond_to?(:job) ? deploy.job : deploy)
      content << " [Process ID: #{job.pid}]"
    end

    if deploy.finished?
      content << ". Started "
      content << render_time(deploy.start_time, current_user.time_format)
      content << ", took #{duration_text deploy.duration}."
    end

    content_tag :div, content, class: "alert #{status_alert(deploy.status)}"
  end

  def duration_text(duration)
    Time.at(duration).utc.strftime('%H:%M:%S')
  end
end
