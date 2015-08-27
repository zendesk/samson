class AddClusterToDeployGroup < ActiveRecord::Migration
  def change
    change_table :deploy_groups do |t|
      t.references :kubernetes_cluster
      t.string :kubernetes_namespace
    end
  end
end
