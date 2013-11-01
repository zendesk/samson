class AddEnvironmentsToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :environments, :text
  end
end
