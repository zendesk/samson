class AddVersionBumpComponentToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :version_bump_component, :string
  end
end
