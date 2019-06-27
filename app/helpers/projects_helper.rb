# frozen_string_literal: true
module ProjectsHelper
  # keep star classes in sync with app/assets/javascripts/projects.js
  # and projects#index
  def star_for_project(project)
    starred = current_user.starred_project?(project)

    content_tag :span do
      link_to(
        '', project_stars_path(project),
        class: "glyphicon glyphicon-star star project-star #{"starred" if starred}",
        data: {method: :post, remote: true},
        title: "#{starred ? "Unstar" : "Star"} this project"
      )
    end
  end

  def deployment_alert_title(deploy)
    failed_at = deploy.updated_at.strftime('%Y/%m/%d %H:%M:%S')
    reference = deploy.short_reference
    username = deploy.user.name
    "#{failed_at} Last deployment failed! #{username} failed to deploy '#{reference}'"
  end

  def job_state_class(job)
    job.succeeded? ? 'success' : 'failed'
  end

  def admin_for_project?
    current_user.admin_for?(@project)
  end

  def deployer_for_project?
    current_user.deployer_for?(@project)
  end

  def repository_web_link(project)
    if project.github?
      render partial: 'shared/github_link', locals: {project: project}
    elsif project.gitlab?
      render partial: 'shared/gitlab_link', locals: {project: project}
    else
      ""
    end
  end

  def docker_build_methods_help_text
    help_texts = Project::DOCKER_BUILD_METHODS.map do |method|
      if method[:help_text].present?
        content_tag(:b, "#{method[:label]}: ") << method[:help_text]
      end
    end.compact
    safe_join(help_texts, "<br/><br/>".html_safe)
  end
end
