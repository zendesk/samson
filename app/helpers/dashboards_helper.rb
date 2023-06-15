# frozen_string_literal: true
module DashboardsHelper
  def project_has_different_deploys?(deploy_group_versions)
    deploy_group_versions.values.map(&:reference).uniq.count > 1
  end

  def dashboard_project_row_style(project_id)
    project_versions = @versions[project_id].values.map(&:reference).uniq.count
    case project_versions
    when 0
      'class=no-deploys'
    when 1
      ''
    else
      'class=warning'
    end
  end

  def display_version(project_id, group_id)
    version = @versions[project_id][group_id]
    version.nil? ? "" : link_to(version[:reference], project_deploy_path(project_id: project_id, id: version[:id]))
  end
end
