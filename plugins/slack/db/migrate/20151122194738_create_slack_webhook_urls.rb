class CreateSlackWebhookUrls < ActiveRecord::Migration
  def change
    create_table :slack_webhook_urls do |t|
      t.string :name, null: false
      t.text :webhook_url, null: false
      t.integer :stage_id, null: false

      t.timestamps
    end

    add_index :slack_webhook_urls, :stage_id
  end
end
