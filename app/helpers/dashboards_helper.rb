module DashboardsHelper
  def project_has_different_deploys?(deploy_group_versions)
    deploy_group_versions.values.map(&:reference).uniq.count > 1
  end
end
