module ProjectsHelper
  include EnvironmentsHelper

  def last_n(list)
    [list.count, 5].min
  end

  def job_state_class(job)
    if job.succeeded?
      "success"
    else
      "failed"
    end
  end

  def project_form_legend
    if project.new_record?
      "New Project"
    else
      "Editing #{project.name}"
    end
  end
end
