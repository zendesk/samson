# frozen_string_literal: true
class MoveVaultInstanceToId < ActiveRecord::Migration[5.0]
  class VaultServer < ActiveRecord::Base
    self.table_name = :vault_servers
  end

  class DeployGroup < ActiveRecord::Base
    self.table_name = :deploy_groups
  end

  def up
    add_column :deploy_groups, :vault_server_id, :integer

    DeployGroup.where.not(vault_instance: nil).each do |dg|
      dg.update_column(:vault_server_id, VaultServer.find_by_name(dg.vault_instance)&.id)
    end

    remove_column :deploy_groups, :vault_instance
  end

  def down
    add_column :deploy_groups, :vault_instance, :string

    DeployGroup.where.not(vault_server_id: nil).each do |dg|
      dg.update_column(:vault_instance, VaultServer.find_by_id(dg.vault_server_id)&.name)
    end

    remove_column :deploy_groups, :vault_server_id
  end
end
