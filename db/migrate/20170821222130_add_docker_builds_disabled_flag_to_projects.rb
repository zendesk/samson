# frozen_string_literal: true
class AddDockerBuildsDisabledFlagToProjects < ActiveRecord::Migration[5.1]
  def change
    add_column :projects, :docker_image_building_disabled, :boolean, default: false, null: false
  end
end
