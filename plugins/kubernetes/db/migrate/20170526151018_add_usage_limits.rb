# frozen_string_literal: true
class AddUsageLimits < ActiveRecord::Migration[5.1]
  def change
    create_table :kubernetes_usage_limits do |t|
      t.integer :project_id
      t.integer :scope_id
      t.string :scope_type
      t.integer :memory, null: false
      t.decimal :cpu, precision: 4, scale: 2, null: false
      t.index :project_id
      t.index [:scope_type, :scope_id, :project_id],
        name: 'index_kubernetes_usage_limits_on_scope', unique: true, length: {scope_type: 20}
      t.timestamps
    end
  end
end
