class CorrectRoleServiceIndex < ActiveRecord::Migration
  def change
    add_index :kubernetes_roles, [:service_name, :project_id, :deleted_at], name: 'index_kubernetes_roles_on_service_name', unique: true, length: {service_name: 191}
    remove_index :kubernetes_roles, column: [:service_name, :deleted_at], name: 'index_kubernetes_roles_on_service_name_and_deleted_at', unique: true, length: {service_name: 191}
  end
end
