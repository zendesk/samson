# frozen_string_literal: true
class MakeKubernetesServicesUnique < ActiveRecord::Migration[4.2]
  def change
    add_index :kubernetes_roles, [:service_name, :deleted_at], unique: true, length: {service_name: 191}
  end
end
