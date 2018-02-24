# frozen_string_literal: true
class CreateRollbarWebhooks < ActiveRecord::Migration[5.1]
  def change
    create_table :rollbar_webhooks do |t|
      t.text :webhook_url, null: false
      t.string :access_token, null: false
      t.string :environment, null: false
      t.integer :stage_id, null: false
      t.timestamps

      t.index :stage_id
    end
  end
end
