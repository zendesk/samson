# frozen_string_literal: true
# rubocop:disable Layout/LineLength
class AddEnvironmentVariables < ActiveRecord::Migration[4.2]
  def change
    create_table :environment_variables do |t|
      t.string :name, null: false
      t.string :value, null: false
      t.integer :parent_id, null: false
      t.string :parent_type, null: false
      t.integer :deploy_group_id
    end
    add_index :environment_variables, [:parent_id, :parent_type, :name, :deploy_group_id], unique: true, name: "environment_variables_unique_deploy_group_id", length: {name: 191, parent_type: 191}

    create_table :environment_variable_groups do |t|
      t.string :name, null: false
    end
    add_index :environment_variable_groups, :name, unique: true, length: 191

    create_table :stage_environment_variable_groups do |t|
      t.integer :stage_id, :environment_variable_group_id, null: false
    end

    add_index :stage_environment_variable_groups, [:stage_id, :environment_variable_group_id], unique: true, name: "stage_environment_variable_groups_unique_group_id"
    add_index :stage_environment_variable_groups, :environment_variable_group_id, name: "stage_environment_variable_groups_group_id"
  end
end
# rubocop:enable Layout/LineLength
