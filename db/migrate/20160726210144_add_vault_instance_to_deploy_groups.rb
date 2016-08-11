# frozen_string_literal: true
class AddVaultInstanceToDeployGroups < ActiveRecord::Migration
  def change
    add_column :deploy_groups, :vault_instance, :string, null: true
  end
end
