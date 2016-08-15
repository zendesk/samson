# frozen_string_literal: true
class CreateDeployResponseUrlTable < ActiveRecord::Migration
  def change
    create_table :deploy_response_urls do |t|
      t.integer :deploy_id, null: false
      t.string :response_url, null: false

      t.timestamps null: false
    end
  end
end
