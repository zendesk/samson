# frozen_string_literal: true
class AddVaultServers < ActiveRecord::Migration[5.0]
  def change
    create_table :vault_servers do |t|
      t.string :name, :address, null: false
      t.string :encrypted_token, :encrypted_token_iv, :encryption_key_sha, null: false
      t.boolean :tls_verify, default: false, null: false
      t.text :ca_cert
      t.timestamps
    end

    add_index :vault_servers, :name, unique: true, length: {name: 191}
  end
end
