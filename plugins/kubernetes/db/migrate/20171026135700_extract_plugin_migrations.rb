# frozen_string_literal: true
class ExtractPluginMigrations < ActiveRecord::Migration[5.1]
  class KubernetesRelease < ActiveRecord::Base
  end

  def up
    remove_column :kubernetes_releases, :build_id if KubernetesRelease.columns_hash.key?('build_id')
  end

  def down
    add_column :kubernetes_releases, :build_id, :string
    add_index :kubernetes_releases, :build_id
  end
end
