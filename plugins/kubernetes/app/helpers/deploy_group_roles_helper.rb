# frozen_string_literal: true
# NOTE: using kubernetes namespace resulted in a strange error on every page
module DeployGroupRolesHelper
  def kubernetes_deploy_group_role_replica(role, dgr)
    if dgr.delete_resource?
      icon_tag :remove, title: "Marked for deletion"
    else
      html = "".html_safe
      html << dgr.replicas.to_s
      if role.autoscaled?
        html << " "
        html << icon_tag(
          :scale,
          title: "Replicas managed externally, minimum replicas needed for deployment, actual count might be higher."
        )
      end
      html
    end
  end
end
