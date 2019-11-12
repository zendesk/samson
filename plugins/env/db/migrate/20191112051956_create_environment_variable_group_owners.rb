# frozen_string_literal: true
class CreateEnvironmentVariableGroupOwners < ActiveRecord::Migration[5.2]
  def change
    create_table :environment_variable_group_owners do |t|
      t.string :name, null: false
      t.references :environment_variable_group,
        index: {name: "index_environment_variable_group_owners_group_id"}, null: false
      t.timestamps
    end
  end
end
