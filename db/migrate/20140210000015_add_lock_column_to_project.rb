class AddLockColumnToProject < ActiveRecord::Migration
  def change
    add_column :projects, :repo_lock, :text
  end
end
