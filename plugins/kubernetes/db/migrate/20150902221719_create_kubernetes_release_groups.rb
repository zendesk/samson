# frozen_string_literal: true
class CreateKubernetesReleaseGroups < ActiveRecord::Migration[4.2]
  def change
    create_table :kubernetes_release_groups do |t|
      t.references :build, null: false, index: true
      t.references :user
      t.text :comment
      t.timestamps
    end
  end
end
