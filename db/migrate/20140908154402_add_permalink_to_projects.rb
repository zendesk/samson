class AddPermalinkToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :permalink, :string
    add_index :projects, :permalink, unique: true

    Project.reset_column_information

    Project.find_each do |project|
      project.send(:generate_permalink)
      project.update_column(:permalink, project.permalink)
    end

    change_column :projects, :permalink, :string, null: false
  end
end
