# frozen_string_literal: true
class CreateOutboundWebhooks < ActiveRecord::Migration
  def change
    create_table :outbound_webhooks do |t|
      t.timestamps null: false
      t.timestamp :deleted_at, default: false

      t.integer :project_id, default: false
      t.integer :stage_id, default: false

      t.string :url
      t.string :username
      t.string :password
    end

    add_index :outbound_webhooks, :deleted_at
  end
end
