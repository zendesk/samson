# frozen_string_literal: true
class AddOwnersToEnvGroups < ActiveRecord::Migration[5.2]
  def change
    add_column :environment_variable_groups, :owners, :string
  end
end
