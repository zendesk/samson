module ProjectsHelper
  def star_for_project(project)
    content_tag :span, class: "star" do
      if current_user.starred_project?(project)
        path = star_path(id: project)
        options = {
          class: "glyphicon glyphicon-star",
          method: :delete,
          title: "Unstar this project"
        }
      else
        path = stars_path(id: project)
        options = {
          class: "glyphicon glyphicon-star-empty",
          method: :post,
          title: "Star this project"
        }
      end

      link_to "", path, options.merge(remote: true)
    end
  end

  def job_state_class(job)
    if job.succeeded?
      "success"
    else
      "failed"
    end
  end
end
