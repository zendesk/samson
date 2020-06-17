# frozen_string_literal: true
class CreateProjects < ActiveRecord::Migration[4.2]
  def change
    create_table :projects do |t|
      t.string :name, null: false
      t.string :repository_url, null: false

      t.datetime :deleted_at
      t.timestamps
    end
  end
end
