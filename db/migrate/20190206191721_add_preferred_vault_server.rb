# frozen_string_literal: true

class AddPreferredVaultServer < ActiveRecord::Migration[5.2]
  def change
    add_column :vault_servers, :preferred_reader, :boolean, default: false, null: false
  end
end
