module ProjectsHelper
  include EnvironmentsHelper

  def last_n(list)
    [list.count, 5].min
  end

  def job_state_class(job)
    if job.failed?
      "failed"
    else
      "success"
    end
  end

  def project_form_method
    if project.new_record?
      :post
    else
      :put
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
