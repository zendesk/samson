# frozen_string_literal: true
class AddVaultInstanceToDeployGroups < ActiveRecord::Migration[4.2]
  def change
    add_column :deploy_groups, :vault_instance, :string, null: true
  end
end
