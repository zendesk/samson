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
      content << relative_time(deploy.started_at)
      job = (deploy.respond_to?(:job) ? deploy.job : deploy)
      content << " [Process ID: #{job.pid}]"
    end

    if deploy.finished?
      content << " "
      if deploy.started_at
        content << render_time(deploy.started_at, current_user.time_format)
        if deploy.finished_at
          content << ", it took #{duration_text(deploy.started_at - deploy.finished_at)}."
        end
      end
    end

    content_tag :div, content, class: "alert #{status_alert(deploy.status)}"
  end

  def duration_text(duration)
    duration = duration.to_i
    minutes = duration / 60
    seconds = duration % 60

    text = "".dup
    text << "#{minutes} minute".pluralize(minutes) if minutes.nonzero?
    text << " #{seconds} second".pluralize(seconds) if seconds.nonzero? || text.empty?
    text
  end
end
