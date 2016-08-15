# frozen_string_literal: true
module ProjectsHelper
  def star_for_project(project)
    content_tag :span, class: 'star' do
      if current_user.starred_project?(project)
        path = star_path(id: project)
        options = {
          class: 'glyphicon glyphicon-star',
          method: :delete,
          title: 'Unstar this project'
        }
      else
        path = stars_path(id: project)
        options = {
          class: 'glyphicon glyphicon-star-empty',
          method: :post,
          title: 'Star this project'
        }
      end

      link_to '', path, options.merge(remote: true)
    end
  end

  def deployment_alert_title(deploy)
    failed_at = deploy.updated_at.strftime('%Y/%m/%d %H:%M:%S')
    reference = deploy.short_reference
    username = deploy.user.name
    "#{failed_at} Last deployment failed! #{username} failed to deploy '#{reference}'"
  end

  def job_state_class(job)
    if job.succeeded?
      'success'
    else
      'failed'
    end
  end

  def admin_for_project?
    current_user.admin_for?(@project)
  end

  def deployer_for_project?
    current_user.deployer_for?(@project)
  end

  def repository_web_link(project)
    if project.github?
      render partial: 'shared/github_link', locals: { project: project }
    elsif project.gitlab?
      render partial: 'shared/gitlab_link', locals: { project: project }
    else
      ""
    end
  end
end
