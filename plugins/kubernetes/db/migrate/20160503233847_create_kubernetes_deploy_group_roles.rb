# frozen_string_literal: true
class CreateKubernetesDeployGroupRoles < ActiveRecord::Migration[4.2]
  def change
    create_table :kubernetes_deploy_group_roles do |t|
      t.integer :project_id, :deploy_group_id, :replicas, :ram, null: false
      t.decimal :cpu, precision: 4, scale: 2, null: false
      t.string :name, null: false
    end
    add_index :kubernetes_deploy_group_roles, [:project_id, :deploy_group_id, :name],
      name: 'index_kubernetes_deploy_group_roles_on_project_id', length: {name: 191}
    add_index :kubernetes_deploy_group_roles, :deploy_group_id
  end
end
