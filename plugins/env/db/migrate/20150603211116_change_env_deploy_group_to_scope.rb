# frozen_string_literal: true
# rubocop:disable Layout/LineLength
class ChangeEnvDeployGroupToScope < ActiveRecord::Migration[4.2]
  def change
    remove_index :environment_variables, name: "environment_variables_unique_deploy_group_id"
    add_column :environment_variables, :scope_type, :string
    rename_column :environment_variables, :deploy_group_id, :scope_id

    EnvironmentVariable.update_all scope_type: "DeployGroup"

    add_index :environment_variables, [:parent_id, :parent_type, :name, :scope_type, :scope_id], unique: true, name: "environment_variables_unique_scope", length: {name: 191, parent_type: 191, scope_type: 191}

    add_column :environment_variable_groups, :comment, :text
  end
end
# rubocop:enable Layout/LineLength
