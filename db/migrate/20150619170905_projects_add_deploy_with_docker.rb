class ProjectsAddDeployWithDocker < ActiveRecord::Migration
  def change
    add_column :projects, :deploy_with_docker, :boolean, default: false, null: false
  end
end
