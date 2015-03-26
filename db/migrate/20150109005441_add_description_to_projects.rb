class AddDescriptionToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :description, :text, limit: 65535
    add_column :projects, :owner, :string, limit: 255
  end
end
