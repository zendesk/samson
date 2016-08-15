# frozen_string_literal: true
class CreateProjects < ActiveRecord::Migration
  def change
    create_table :projects do |t|
      t.string :name, null: false
      t.string :repository_url, null: false

      t.timestamp :deleted_at
      t.timestamps
    end
  end
end
