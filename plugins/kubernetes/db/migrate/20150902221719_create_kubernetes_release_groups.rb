class CreateKubernetesReleaseGroups < ActiveRecord::Migration
  def change
    create_table :kubernetes_release_groups do |t|
      t.references :build, null: false, index: true
      t.references :user
      t.text :comment
      t.timestamps
    end
  end
end
