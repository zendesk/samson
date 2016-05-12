class MakeKubernetesServicesUnique < ActiveRecord::Migration
  def change
    add_index :kubernetes_roles, [:service_name, :deleted_at], unique: true, length: {service_name: 191}
  end
end
