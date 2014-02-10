class MakeLockBoolean < ActiveRecord::Migration
  def change
    change_column :projects, :repo_lock, :boolean
  end
end
