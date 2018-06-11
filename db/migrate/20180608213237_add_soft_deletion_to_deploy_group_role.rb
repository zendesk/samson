class AddSoftDeletionToDeployGroupRole < ActiveRecord::Migration[5.2]
  def change
  	add_column :kubernetes_deploy_group_roles, :deleted_at, :timestamp
  end
end
