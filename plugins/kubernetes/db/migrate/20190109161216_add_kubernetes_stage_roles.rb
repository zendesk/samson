# frozen_string_literal: true

class AddKubernetesStageRoles < ActiveRecord::Migration[5.2]
  def change
    create_table :kubernetes_stage_roles do |t|
      t.column :stage_id, :integer, null: false
      t.column :kubernetes_role_id, :integer, null: false
      t.column :ignored, :boolean, null: false, default: false
    end
  end
end
