class AddSoftDeleteToKubernetesRole < ActiveRecord::Migration
  def change
    add_column :kubernetes_roles, :deleted_at, :timestamp
  end
end
