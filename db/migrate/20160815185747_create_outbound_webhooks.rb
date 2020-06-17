# frozen_string_literal: true
class CreateOutboundWebhooks < ActiveRecord::Migration[4.2]
  def change
    create_table :outbound_webhooks do |t|
      t.timestamps null: false
      t.datetime :deleted_at

      t.integer :project_id, null: false
      t.integer :stage_id, null: false

      t.string :url, null: false
      t.string :username
      t.string :password
    end

    add_index :outbound_webhooks, :deleted_at
    add_index :outbound_webhooks, :project_id
  end
end
