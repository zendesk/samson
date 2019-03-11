# frozen_string_literal: true
class AddEnvValueToDeployGroup < ActiveRecord::Migration[4.2]
  class DeployGroup < ActiveRecord::Base
  end

  def change
    add_column :deploy_groups, :env_value, :string
    DeployGroup.update_all('env_value = name')
    change_column_null :deploy_groups, :env_value, false
  end
end
