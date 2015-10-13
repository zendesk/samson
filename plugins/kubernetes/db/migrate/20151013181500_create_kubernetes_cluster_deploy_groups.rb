class CreateKubernetesClusterDeployGroups < ActiveRecord::Migration
  def up
    create_table :kubernetes_cluster_deploy_groups do |t|
      t.belongs_to :kubernetes_cluster, null: false, index: true
      t.belongs_to :deploy_group, null: false, index: true
      t.string :namespace, null: false
      t.timestamps
    end
  end

  def down
    drop_table :kubernetes_cluster_deploy_groups
  end
end
