# frozen_string_literal: true
class KubernetesReleaseAsChildToGroup < ActiveRecord::Migration[4.2]
  def up
    change_table :kubernetes_releases do |t|
      t.remove :build_id
      t.remove :user_id
      t.references :kubernetes_release_group, index: true, after: :id
    end
  end

  def down
    change_table :kubernetes_releases do |t|
      t.remove :kubernetes_release_group_id
      t.references :build, null: false, index: true
      t.references :user
    end
  end
end
