# frozen_string_literal: true

class AddVersionedKvToVaultServer < ActiveRecord::Migration[5.2]
  def change
    add_column :vault_servers, :versioned_kv, :boolean, null: false, default: false
  end
end
