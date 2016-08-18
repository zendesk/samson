class CreateOutboundWebhooks < ActiveRecord::Migration
  def change
    create_table :outbound_webhooks do |t|

      t.timestamps null: false
      t.timestamp :deleted_at, default: nil

      t.integer :project_id
      t.integer :stage_id

      t.string :url
      t.string :username
      t.string :password
    end

    add_index :outbound_webhooks, :deleted_at
  end
end
