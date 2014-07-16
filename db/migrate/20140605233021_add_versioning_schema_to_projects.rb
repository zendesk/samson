class AddVersioningSchemaToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :versioning_schema, :string
  end
end
