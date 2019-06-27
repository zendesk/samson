# frozen_string_literal: true

class AlterSecretSharingGrantsIndexes < ActiveRecord::Migration[5.2]
  def change
    remove_index :secret_sharing_grants, :key
    remove_index :secret_sharing_grants, [:project_id, :key]
    # https://dev.mysql.com/doc/refman/8.0/en/innodb-restrictions.html
    # Safe allowed column prefix index length is 191
    add_index :secret_sharing_grants, [:key], length: {key: 191}
    add_index :secret_sharing_grants, [:project_id, :key], unique: true, length: {key: 160}
  end
end
