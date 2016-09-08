# frozen_string_literal: true
class DeploysIndexDeletedAt < ActiveRecord::Migration[4.2]
  def change
    add_index :deploys, [:deleted_at]
    add_index :deploys, [:job_id, :deleted_at]
    add_index :deploys, [:stage_id, :deleted_at]

    remove_index :deploys, column: :created_at
    remove_index :deploys, column: :job_id
    remove_index :deploys, column: :stage_id
  end
end
