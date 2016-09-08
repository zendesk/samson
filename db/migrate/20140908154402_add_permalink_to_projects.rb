# frozen_string_literal: true
class AddPermalinkToProjects < ActiveRecord::Migration[4.2]
  def change
    add_column :projects, :permalink, :string
    add_index :projects, :permalink, unique: true, length: 191

    Project.reset_column_information

    Project.with_deleted do
      Project.find_each do |project|
        project.send(:generate_permalink)
        project.update_column(:permalink, project.permalink)
      end
    end

    change_column :projects, :permalink, :string, null: false
  end
end
