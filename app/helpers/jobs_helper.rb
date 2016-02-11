module JobsHelper
  def job_page_title
    "#{@project.name} deploy (#{@job.status})"
  end
end
