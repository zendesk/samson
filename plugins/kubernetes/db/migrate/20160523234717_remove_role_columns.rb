# frozen_string_literal: true
class RemoveRoleColumns < ActiveRecord::Migration[4.2]
  def up
    remove_column :kubernetes_roles, :cpu
    remove_column :kubernetes_roles, :ram
    remove_column :kubernetes_roles, :replicas
  end

  def down
    add_column :kubernetes_roles, :cpu, :decimal, precision: 4, scale: 2, null: false, default: 0
    add_column :kubernetes_roles, :ram, :integer, null: false, default: 0
    add_column :kubernetes_roles, :replicas, :integer, null: false, default: 0

    change_column_default :kubernetes_roles, :cpu, nil
    change_column_default :kubernetes_roles, :ram, nil
    change_column_default :kubernetes_roles, :replicas, nil
  end
end
