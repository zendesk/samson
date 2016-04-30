class NormalizeProjectId < ActiveRecord::Migration
  def up
    add_column :kubernetes_releases, :project_id, :integer
    ActiveRecord::Base.connection.execute 'UPDATE kubernetes_releases JOIN builds ON kubernetes_releases.build_id = builds.id SET kubernetes_releases.project_id = builds.project_id'
    change_column_null :kubernetes_releases, :project_id, false
  end

  def down
    remove_column :kubernetes_releases, :project_id
  end
end
