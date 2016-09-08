# frozen_string_literal: true
class RemoveReleaseGroups < ActiveRecord::Migration[4.2]
  def change
    add_reference :kubernetes_releases, :build, index: true
    add_reference :kubernetes_releases, :user
    add_reference :kubernetes_release_docs, :deploy_group

    remove_reference :kubernetes_releases, :deploy_group
    remove_reference :kubernetes_releases, :kubernetes_release_group, index: true
    drop_table :kubernetes_release_groups
  end
end
