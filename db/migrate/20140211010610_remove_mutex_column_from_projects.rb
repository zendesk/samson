class RemoveMutexColumnFromProjects < ActiveRecord::Migration
  def change
    remove_column :projects, :repo_lock
  end
end
