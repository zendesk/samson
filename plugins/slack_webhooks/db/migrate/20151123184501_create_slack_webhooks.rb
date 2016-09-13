# frozen_string_literal: true
class CreateSlackWebhooks < ActiveRecord::Migration[4.2]
  def change
    create_table :slack_webhooks do |t|
      t.text :webhook_url, null: false
      t.string :channel
      t.integer :stage_id, null: false

      t.timestamps
    end

    add_index :slack_webhooks, :stage_id
  end
end
