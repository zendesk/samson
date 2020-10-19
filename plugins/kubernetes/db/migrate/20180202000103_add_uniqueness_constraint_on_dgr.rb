# frozen_string_literal: true

class AddUniquenessConstraintOnDgr < ActiveRecord::Migration[5.1]
  class KubernetesDeployGroupRole < ActiveRecord::Base
  end

  def change
    bad = KubernetesDeployGroupRole.all.group_by { |f| [f.project_id, f.kubernetes_role_id, f.deploy_group_id] }.
      select { |_, v| v.size > 1 }.
      flat_map { |_, v| v[0..] }

    write "deleting #{bad.size} duplicate DeployGroupRoles:"
    write bad.map(&:attributes)

    remove_index :kubernetes_deploy_group_roles,
      column: ['project_id', 'deploy_group_id', 'kubernetes_role_id'],
      name: 'index_kubernetes_deploy_group_roles_on_project_id'
    add_index :kubernetes_deploy_group_roles,
      [:project_id, :deploy_group_id, :kubernetes_role_id],
      unique: true,
      name: 'index_kubernetes_deploy_group_roles_on_project_dg_kr'
  end
end
