class AddSlackTimestampForThreading < ActiveRecord::Migration[5.0]
  def change
    create_table :slack_webhook_threads do |t|
      t.integer :deploy_id, null: false
      t.string :slack_ts, null: false
      t.timestamps
    end

    add_index :slack_webhook_threads, :deploy_id
  end
end
