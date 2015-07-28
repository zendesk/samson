class CreateKubernetesReleases < ActiveRecord::Migration
  def change
    create_table :kubernetes_releases do |t|
      t.references :build, null: false, index: true
      t.references :user, null: false
      t.references :deploy_group, null: false, index: true
      t.string :role, null: false
      t.integer :replicas, null: false
      t.text :replication_controller_doc
      t.string :status
      t.timestamps
      t.datetime :deploy_finished_at
      t.datetime :destroyed_at
    end
  end
end
