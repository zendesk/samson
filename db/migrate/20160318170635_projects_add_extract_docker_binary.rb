class ProjectsAddExtractDockerBinary < ActiveRecord::Migration
  def change
    add_column :projects, :extract_docker_packaged_artifact, :boolean, default: true, null: false
  end
end
