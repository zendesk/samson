class AddVersioningDataToExistingProjects < ActiveRecord::Migration
  def up
    Project.where("release_branch IS NOT NULL").update_all("versioning_schema = 'v{number}', version_bump_component = 'number'")
  end
end
