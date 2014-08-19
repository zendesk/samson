module JobsHelper
  def job_page_title
    "#{@project.name} deploy (#{@job.status})"
  end

  def job_active?
    @job.active? && (JobExecution.find_by_id(@job.id) || JobExecution.enabled)
  end

  def job_status_panel(job)
    mapping = {
      "succeeded" => "success",
      "failed"    => "danger",
      "errored"   => "warning"
    }

    status = mapping.fetch(job.status, "info")

    content = h job.summary

    if job.finished?
      content << " "
      content << content_tag(:span, job.created_at.rfc822, data: { time: datetime_to_js_ms(job.created_at) }, class: 'mouseover')
    end

    content_tag :div, content.html_safe, class: "alert alert-#{status}"
  end

  def can_create_job?
    current_user.is_super_admin? || current_user.is_admin?
  end

end
