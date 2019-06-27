# frozen_string_literal: true
class AddSecrets < ActiveRecord::Migration[4.2]
  def change
    create_table :secrets, id: false do |t|
      t.string :id, primary_key: true, null: false
      t.string :encrypted_value, :encrypted_value_iv, :encryption_key_sha, null: false
      t.integer :updater_id, :creator_id, null: false
      t.timestamps null: false
    end
    add_index :secrets, :id, unique: true, length: {id: 191}
  end
end
