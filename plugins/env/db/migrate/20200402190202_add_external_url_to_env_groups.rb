# frozen_string_literal: true
class AddExternalUrlToEnvGroups < ActiveRecord::Migration[6.0]
  def change
    add_column :environment_variable_groups, :external_url, :string
  end
end
