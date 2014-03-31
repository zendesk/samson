class AddDeployOnReleaseToStages < ActiveRecord::Migration
  def change
    add_column :stages, :deploy_on_release, :boolean, default: false
  end
end
