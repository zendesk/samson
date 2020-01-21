# frozen_string_literal: true
class CreateExternalEnvironmentVariableGroups < ActiveRecord::Migration[6.0]
  def change
    create_table :external_environment_variable_groups do |t|
      t.string :name, null: false
      t.string :description, limit: 1024
      t.string :url, null: false
      t.references :project, index: true, null: false
      t.timestamps
    end
  end
end
