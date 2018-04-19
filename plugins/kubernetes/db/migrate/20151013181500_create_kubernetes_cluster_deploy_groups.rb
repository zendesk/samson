# frozen_string_literal: true
class CreateKubernetesClusterDeployGroups < ActiveRecord::Migration[4.2]
  def up
    create_table :kubernetes_cluster_deploy_groups do |t|
      t.belongs_to :kubernetes_cluster,
        null: false, index: {name: 'index_kuber_cluster_deploy_groups_on_kuber_cluster_id'}
      t.belongs_to :deploy_group, null: false, index: true
      t.string :namespace, null: false
      t.timestamps null: false
    end
  end

  def down
    drop_table :kubernetes_cluster_deploy_groups
  end
end
