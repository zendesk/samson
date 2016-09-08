# frozen_string_literal: true
class ProjectsAddDeployWithDocker < ActiveRecord::Migration[4.2]
  def change
    add_column :projects, :deploy_with_docker, :boolean, default: false, null: false
  end
end
