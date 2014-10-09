module ProjectsHelper
  cattr_accessor(:github_status_cache_key, instance_writer: false) { 'github-status-ok' }

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
    return true unless (status_url = Rails.application.config.samson.github.status_url)

    github_ok = Rails.cache.read(github_status_cache_key)

    if github_ok.nil?
      response = Faraday.get('https://' + status_url + '/api/status.json')
      github_ok = response.status == 200 && JSON.parse(response.body)['status'] == 'good'

      if github_ok
        Rails.cache.write(github_status_cache_key, github_ok, expires_in: 5.minutes)
      end
    end

    github_ok
  rescue Faraday::ClientError
    false
  end
end
