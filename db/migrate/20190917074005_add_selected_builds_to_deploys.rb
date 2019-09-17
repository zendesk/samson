class AddSelectedBuildsToDeploys < ActiveRecord::Migration[5.2]
  def change
    add_column :deploys, :selected_builds, :string
  end
end
