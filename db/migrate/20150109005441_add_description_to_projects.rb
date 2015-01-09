class AddDescriptionToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :description, :text
    add_column :projects, :owner, :string
  end
end
