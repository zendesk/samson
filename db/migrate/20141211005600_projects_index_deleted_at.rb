class ProjectsIndexDeletedAt < ActiveRecord::Migration
  def change
    add_index :projects, [:permalink, :deleted_at]
    add_index :projects, [:token, :deleted_at]

    remove_index :projects, column: :permalink
    remove_index :projects, column: :token
  end
end
