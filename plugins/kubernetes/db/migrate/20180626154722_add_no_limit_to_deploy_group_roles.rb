# frozen_string_literal: true
class AddNoLimitToDeployGroupRoles < ActiveRecord::Migration[5.2]
  def change
    add_column :kubernetes_deploy_group_roles, :no_cpu_limit, :boolean, default: false, null: false
    add_column :kubernetes_release_docs, :no_cpu_limit, :boolean, default: false, null: false
  end
end
