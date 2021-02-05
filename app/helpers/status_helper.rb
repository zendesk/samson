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

  def status_panel(deployable)
    is_deploy = deployable.is_a?(Deploy)

    content = h deployable.summary
    if deployable.active?
      content << content_tag(:br)
      content << "Started "
      content << relative_time(deployable.start_time)
      job = (is_deploy ? deployable.job : deployable)
      content << " [Process ID: #{job.pid}]"
      if is_deploy
        content << content_tag(:br)
        content << "Expected duration: #{duration_text deployable.stage.average_deploy_time}"
      end
    end

    if deployable.finished?
      content << ". Started "
      content << render_time(deployable.start_time, current_user.time_format)
      content << ", took #{duration_text deployable.duration}."
    end

    content_tag :div, content, class: "alert #{status_alert(deployable.status)}"
  end

  def duration_text(duration)
    duration ? Time.at(duration).utc.strftime('%H:%M:%S') : ''
  end
end
