# frozen_string_literal: true
module JobsHelper
  def job_page_title
    "#{@project.name} deploy (#{@job.status})"
  end

  def job_status_badge(job)
    content_tag :span, job.status.titleize, class: "label #{status_label(job.status)}"
  end
end
