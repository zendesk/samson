# frozen_string_literal: true
class CreateKubernetesReleaseDocs < ActiveRecord::Migration[4.2]
  def change
    create_table :kubernetes_release_docs do |t|
      t.references :kubernetes_role, null: false, index: true
      t.references :kubernetes_release, null: false, index: true
      t.integer :replica_count, null: false
      t.string :replication_controller_name
      t.text :replication_controller_doc
      t.string :status
      t.timestamps
    end
  end
end
