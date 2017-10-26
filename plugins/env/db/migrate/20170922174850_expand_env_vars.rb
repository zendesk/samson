# frozen_string_literal: true
class ExpandEnvVars < ActiveRecord::Migration[5.1]
  def up
    change_column :environment_variables, :value, :string, limit: 2048
  end

  def down
    change_column :environment_variables, :value, :string, limit: 255
  end
end
