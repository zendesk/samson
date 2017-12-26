# frozen_string_literal: true
class AddAutoscaledToKubernetesDeployGroupRoles < ActiveRecord::Migration[5.1]
  def change
    add_column :kubernetes_roles, :autoscaled, :boolean, null: false, default: false
  end
end
