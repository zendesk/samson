# frozen_string_literal: true
class CreateWebhooks < ActiveRecord::Migration[4.2]
  def change
    create_table :webhooks do |t|
      t.integer :project_id, null: false
      t.integer :stage_id, null: false
      t.string :branch, null: false

      t.timestamps

      t.index [:project_id, :branch], length: {branch: 191}
      t.index [:stage_id, :branch], unique: true, length: {branch: 191}
    end
  end
end
