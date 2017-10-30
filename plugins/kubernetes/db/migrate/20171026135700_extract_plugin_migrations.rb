# frozen_string_literal: true
class ExtractPluginMigrations < ActiveRecord::Migration[5.1]
  def up
    remove_column :kubernetes_releases, :build_id
  rescue ActiveRecord::StatementInvalid
    # ignore errors since this might have run before as part of 20170824174718_remove_build_from_releases.rb
    nil
  end

  def down
    add_column :kubernetes_releases, :build_id, :string
    add_index :kubernetes_releases, :build_id
  end
end
