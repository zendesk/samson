# frozen_string_literal: true
class AddAutoBuildDockerImageToProjects < ActiveRecord::Migration[4.2]
  def change
    change_table :projects do |t|
      t.boolean :auto_release_docker_image, default: false, null: false
    end
  end
end
