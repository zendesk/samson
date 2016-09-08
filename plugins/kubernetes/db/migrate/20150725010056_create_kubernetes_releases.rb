# frozen_string_literal: true
class CreateKubernetesReleases < ActiveRecord::Migration[4.2]
  def change
    create_table :kubernetes_releases do |t|
      t.references :build, null: false, index: true
      t.references :user
      t.references :deploy_group, null: false, index: true
      t.string :status
      t.datetime :deploy_finished_at
      t.datetime :destroyed_at
      t.timestamps
    end
  end
end
