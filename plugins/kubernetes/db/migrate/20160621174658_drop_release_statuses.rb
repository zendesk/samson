# frozen_string_literal: true
class DropReleaseStatuses < ActiveRecord::Migration[4.2]
  def up
    remove_column :kubernetes_releases, :status
    remove_column :kubernetes_releases, :destroyed_at
    remove_column :kubernetes_releases, :deploy_finished_at
    remove_column :kubernetes_release_docs, :status
    remove_column :kubernetes_release_docs, :replicas_live
    remove_column :kubernetes_release_docs, :replication_controller_name
    remove_column :kubernetes_release_docs, :replication_controller_doc
  end

  def down
    add_column :kubernetes_releases, :status, :string, default: 'created'
    add_column :kubernetes_releases, :destroyed_at, :timestamp
    add_column :kubernetes_releases, :deploy_finished_at, :timestamp
    add_column :kubernetes_release_docs, :status, :string, default: 'created'
    add_column :kubernetes_release_docs, :replicas_live, :integer, limit: 4, default: 0, null: false
    add_column :kubernetes_release_docs, :replication_controller_name, :string, limit: 255
    add_column :kubernetes_release_docs, :replication_controller_doc, :text, limit: 65535
  end
end
