class AddEnvValueToDeployGroup < ActiveRecord::Migration
  def change
    add_column :deploy_groups, :env_value, :string
    DeployGroup.update_all('env_value = name')
    change_column_null :deploy_groups, :env_value, false
  end
end
