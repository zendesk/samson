module ProjectsHelper
  cattr_reader(:github_status_cache_key) { 'github-status-ok' }

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

  def github_ok?
    status_url = Rails.application.config.samson.github.status_url
    github_ok = false

    Rails.cache.fetch(github_status_cache_key, expires_in: 5.minutes) do
      response = Faraday.get("https://#{status_url}/api/status.json")
      github_ok = response.status == 200 && JSON.parse(response.body)['status'] == 'good'
      github_ok || nil # don't cache non-good responses
    end

    github_ok
  rescue Faraday::ClientError
    false
  end
end
