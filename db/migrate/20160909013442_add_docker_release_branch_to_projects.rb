# frozen_string_literal: true
class AddDockerReleaseBranchToProjects < ActiveRecord::Migration[5.0]
  class Project < ActiveRecord::Base; end

  def change
    add_column :projects, :docker_release_branch, :string
    Project.all.each do |project|
      if project.auto_release_docker_image? && project.deploy_with_docker
        project.update(docker_release_branch: project.release_branch)
      end
    end
    remove_column :projects, :deploy_with_docker
    remove_column :projects, :auto_release_docker_image
  end
end
