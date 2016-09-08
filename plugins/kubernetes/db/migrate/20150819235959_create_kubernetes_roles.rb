# frozen_string_literal: true
class CreateKubernetesRoles < ActiveRecord::Migration[4.2]
  def change
    create_table :kubernetes_roles do |t|
      t.references :project, null: false, index: true
      t.string :name, null: false
      t.string :config_file
      t.integer :replicas, null: false
      t.integer :ram, null: false
      t.decimal :cpu, precision: 4, scale: 2, null: false
      t.string :service_name
      t.string :deploy_strategy, null: false
      t.timestamps null: false
    end
  end
end
