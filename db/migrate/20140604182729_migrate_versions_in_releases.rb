class MigrateVersionsInReleases < ActiveRecord::Migration
  def up
    Release.reset_column_information
    Release.update_all(version: "v#{version}")
  end
end
