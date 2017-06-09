# frozen_string_literal: true
class CreateSecretSharingGrants < ActiveRecord::Migration[5.1]
  def change
    create_table :secret_sharing_grants do |t|
      t.string :key, null: false
      t.integer :project_id, null: false
      t.timestamps
      t.index [:key], length: {key: 50}
      t.index [:project_id, :key], unique: true, length: {key: 50}
    end
  end
end
