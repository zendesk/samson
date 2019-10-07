# frozen_string_literal: true

class AddKubernetesNamespaces < ActiveRecord::Migration[5.2]
  def change
    create_table :kubernetes_namespaces do |t|
      t.column :name, :string, null: false
      t.column :comment, :string, limit: 512
      t.timestamps
    end
    add_index :kubernetes_namespaces, :name, unique: true, length: {"name" => 191}

    add_column :projects, :kubernetes_namespace_id, :integer
    add_index :projects, :kubernetes_namespace_id
  end
end
