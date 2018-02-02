# frozen_string_literal: true

class AddUniquenessConstraintOnDgr < ActiveRecord::Migration[5.1]
  def change
    remove_index :kubernetes_deploy_group_roles,
      column: ['project_id', 'deploy_group_id', 'kubernetes_role_id'],
      name: 'index_kubernetes_deploy_group_roles_on_project_id'
    add_index :kubernetes_deploy_group_roles,
      [:project_id, :deploy_group_id, :kubernetes_role_id],
      unique: true,
      name: 'index_kubernetes_deploy_group_roles_on_project_dg_kr'
  end
end
