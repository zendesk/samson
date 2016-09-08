# frozen_string_literal: true
class CreateSlackAppTable < ActiveRecord::Migration[4.2]
  def change
    create_table :slack_identifiers do |t|
      t.integer :user_id
      t.text :identifier, null: false

      t.timestamps null: false
    end
  end
end
